#!/bin/bash

KEY=$(cat config.cfg | grep KEY | awk -F "=" '{print $2}')
ASN=$(cat config.cfg | grep ASN | awk -F "=" '{print $2}')
num_threads=$(cat config.cfg | grep num_threads | awk -F "=" '{print $2}')

export LC_CTYPE=en_US.UTF-8
export LC_ALL=en_US.UTF-8

blocos=$(curl --fail --silent "https://rdap.registro.br/autnum/$ASN" | jq ".links[].href" | awk -F "/ip/" '{print $2}' | grep -v "::" | awk 'NF>0' | awk -F "\"" '{print $1}')

processar_bloco() {
    bloco=$1
    for ip in $(ipcalc $bloco /24 | grep Network | grep "/24" | awk -F " " '{print $2}' | awk -F "/" '{print $1}' | sed 's/.$//'); do
        for UltimoOcteto in $(seq 1 255); do
            CONTAGEM=$(curl  --silent "https://otx.alienvault.com/api/v1/indicators/IPv4/${ip}${UltimoOcteto}/general" -H "X-OTX-API-KEY: $KEY" | jq '.pulse_info.count') 2>/dev/null
            ASN=$(cat config.cfg | grep ASN | awk -F "=" '{print $2}')
            date=$(date '+%Y-%m-%d__%H:%M:%S')
            if [[ $CONTAGEM > 0 ]]; then
                ContagemTags=$(curl  --silent "https://otx.alienvault.com/api/v1/indicators/IPv4/${ip}${UltimoOcteto}/general" -H "X-OTX-API-KEY: $KEY" | jq -r '.pulse_info.pulses[0].tags | length')
                ULTIMO_REPORT=$(curl --silent "https://otx.alienvault.com/api/v1/indicators/IPv4/${ip}${UltimoOcteto}/general" -H "X-OTX-API-KEY: $KEY" | jq '.pulse_info.pulses[0].modified')
                echo "{\"index\":{\"_index\":\"dedoduro\"}}" > teste_$ip$UltimoOcteto.json
                echo "{\"ip\":\"$ip$UltimoOcteto\",\"date\":\"${date}\",\"last_report\":$ULTIMO_REPORT,\"number_report\":\"$ContagemTags\",\"ASN\":\"$ASN\"}" >> teste_$ip$UltimoOcteto.json
                curl --connect-timeout 950 -m 950 --silent -H 'Content-Type: application/json' -XPOST 'cadeolog.com.br:9200/mina/_bulk?pretty' -u elastic:felipe --data-binary @teste_$ip$UltimoOcteto.json >/dev/null
            elif [[ $CONTAGEM == "null" ]]; then
                ContagemTags=$(curl --retry-all-errors --connect-timeout 2500.0 -m 2500.0 --silent "https://otx.alienvault.com/api/v1/indicators/IPv4/${ip}${UltimoOcteto}/general" -H "X-OTX-API-KEY: $KEY" | jq -r '.pulse_info.pulses[0].tags | length')
                ULTIMO_REPORT=$(curl --retry-all-errors --connect-timeout 2500.0 -m 2500.0 --silent "https://otx.alienvault.com/api/v1/indicators/IPv4/${ip}${UltimoOcteto}/general" -H "X-OTX-API-KEY: $KEY" | jq '.pulse_info.pulses[0].modified')
                echo "{\"index\":{\"_index\":\"dedoduro\"}}" > teste_$ip$UltimoOcteto.json
                echo "{\"ip\":\"${ip}${UltimoOcteto}\",\"date\":\"${date}\",\"last_report\":\"${ULTIMO_REPORT}\",\"number_report\":\"${ContagemTags}\",\"ASN\":\"$ASN\"}" >> teste_$ip$UltimoOcteto.json
                curl --connect-timeout 950 -m 950 --silent -H 'Content-Type: application/json' -XPOST 'cadeolog.com.br:9200/mina/_bulk?pretty' -u elastic:felipe --data-binary @teste_$ip$UltimoOcteto.json >/dev/null
            elif [[ $CONTAGEM == 0 ]]; then
                ContagemTags=$(curl --retry-all-errors --connect-timeout 2500.0 -m 2500.0 --silent "https://otx.alienvault.com/api/v1/indicators/IPv4/${ip}${UltimoOcteto}/general" -H "X-OTX-API-KEY: $KEY" | jq -r '.pulse_info.pulses[0].tags | length')
                ULTIMO_REPORT=$(curl --retry-all-errors --connect-timeout 2500.0 -m 2500.0 --silent "https://otx.alienvault.com/api/v1/indicators/IPv4/${ip}${UltimoOcteto}/general" -H "X-OTX-API-KEY: $KEY" | jq '.pulse_info.pulses[0].modified')
                echo "{\"index\":{\"_index\":\"dedoduro\"}}" > teste_$ip$UltimoOcteto.json
                echo "{\"ip\":\"${ip}${UltimoOcteto}\",\"date\":\"${date}\",\"last_report\":\"${ULTIMO_REPORT}\",\"number_report\":\"${ContagemTags}\",\"ASN\":\"$ASN\"}" >> teste_$ip$UltimoOcteto.json
                curl --connect-timeout 950 -m 950 --silent -H 'Content-Type: application/json' -XPOST 'cadeolog.com.br:9200/mina/_bulk?pretty' -u elastic:felipe --data-binary @teste_$ip$UltimoOcteto.json >/dev/null
            else
                ULTIMO_REPORT="Deu ruim"
                ContagemTags="Deu ruim"
                echo "{\"index\":{\"_index\":\"dedoduro\"}}" > teste_$ip$UltimoOcteto.json
                echo "{\"ip\":\"${ip}${UltimoOcteto}\",\"date\":\"${date}\",\"last_report\":\"${ULTIMO_REPORT}\",\"number_report\":\"${ContagemTags}\",\"ASN\":\"$ASN\"}" >> teste_$ip$UltimoOcteto.json
                curl --connect-timeout 950 -m 950 --silent -H 'Content-Type: application/json' -XPOST 'cadeolog.com.br:9200/mina/_bulk?pretty' -u elastic:felipe --data-binary @teste_$ip$UltimoOcteto.json >/dev/null
            fi
        done
    done
}

export -f processar_bloco

echo "$blocos" | xargs -P $num_threads -I {} bash -c 'processar_bloco "$@"' _ {}
