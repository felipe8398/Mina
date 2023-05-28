#!/bin/bash

KEY=$(cat config.cfg | grep KEY | awk -F "=" '{print $2}')
ASN=$(cat config.cfg | grep ASN | awk -F "=" '{print $2}')

export LC_CTYPE=en_US.UTF-8
export LC_ALL=en_US.UTF-8

blocos=$(curl --fail --silent "https://rdap.registro.br/autnum/$ASN" | jq ".links[].href" | awk -F "/ip/" '{print $2}' | grep -v "::" | awk 'NF>0' | awk -F "\"" '{print $1}')

processar_bloco() {
    bloco=$1
    for ip in $(ipcalc $bloco /24 | grep Network | grep "/24" | awk -F " " '{print $2}' | awk -F "/" '{print $1}' | sed 's/.$//'); do
        for UltimoOcteto in $(seq 1 255); do
            MAX_TENTATIVAS=3
            tentativa=1

            while [ $tentativa -le $MAX_TENTATIVAS ]; do
                CONTAGEM=$(curl --retry-all-errors --connect-timeout 50 -m 50 --silent "https://otx.alienvault.com/api/v1/indicators/IPv4/${ip}${UltimoOcteto}/general" -H "X-OTX-API-KEY: $KEY" | jq '.pulse_info.count') 2>/dev/null
                ULTIMO_REPORT=$(curl --retry-all-errors --connect-timeout 50 -m 50 --silent "https://otx.alienvault.com/api/v1/indicators/IPv4/${ip}${UltimoOcteto}/general" -H "X-OTX-API-KEY: $KEY" | jq '.pulse_info.pulses[0].modified')
                date=$(date '+%Y-%m-%d__%H:%M:%S')
                ASN=$(cat config.cfg | grep ASN | awk -F "=" '{print $2}')

                if [[ ! -z $CONTAGEM ]]; then
                    # Os dados foram obtidos corretamente, saia do loop
                    break
                else
                    # Houve falha na obtenção dos dados, tente novamente
                    ((tentativa++))
                    sleep 1  # Aguarda 1 segundo antes de tentar novamente
                fi
            done

            if [[ ! -z $CONTAGEM ]]; then
                ContagemTags=$(curl --retry-all-errors --connect-timeout 50 -m 50 --silent "https://otx.alienvault.com/api/v1/indicators/IPv4/${ip}${UltimoOcteto}/general" -H "X-OTX-API-KEY: $KEY" | jq -r '.pulse_info.pulses[0].tags | length')
                echo "{\"index\":{\"_index\":\"dedoduro\"}}" >teste_$ip$UltimoOcteto.json
                echo "{\"ip\":\"$ip$UltimoOcteto\",\"date\":\"${date}\",\"last_report\":$ULTIMO_REPORT,\"number_report\":\"$ContagemTags\"}" >>teste_$ip$UltimoOcteto.json
                curl --connect-timeout 50 -m 50 --silent -H 'Content-Type: application/json' -XPOST '127.0.0.1:9200/mina/_bulk?pretty' -u elastic:felipe --data-binary @teste_$ip$UltimoOcteto.json >/dev/null
            else
                ULTIMO_REPORT="Não disponível"
                ContagemTags="0"
                echo "{\"index\":{\"_index\":\"dedoduro\"}}" >teste_$ip$UltimoOcteto.json
                echo "{\"ip\":\"$ip$UltimoOcteto\",\"date\":\"${date}\",\"last_report\":\"${ULTIMO_REPORT}\",\"number_report\":\"${ContagemTags}\"}" >>teste_$ip$UltimoOcteto.json
                curl --connect-timeout 50 -m 50 --silent -H 'Content-Type: application/json' -XPOST '127.0.0.1:9200/mina/_bulk?pretty' -u elastic:felipe --data-binary @teste_$ip$UltimoOcteto.json >/dev/null
            fi
        done
    done
}

export -f processar_bloco

num_threads=10

printf "%s\n" "${blocos[@]}" | parallel -j "$num_threads" processar_bloco
