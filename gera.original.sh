#!/bin/bash
# Script para geração de keystore java
# Elaborado por Luis
# Versão 1 em 14-04-2015
# - Gera de forma fixa. Somente incorpora cadeia Serpro Final v4 de produção
# Versão 2 em 08-05-2015
# - Gera keystore para qualquer tipo de cadeia
# - Lista certificados da cadeia para verificação
# Versão 3 em 15-06-2015
# - Usa a pasta ./CAcerts como fonte de recursos e não mais /etc/httpd/conf/ssl.prm/CAcerts
# Versão 4 em 06-12-2016
# - Incorpora outras pastas de pesquisa dos certificados (/etc/pki/tls/certs)
# Versão 4 em 28-03-2018
# - Alterou o número mínimo de certificados de cadeia para 2

search_issuer(){
echo "Procurando o certificado de: $ISSUER"
for i in $(ls -1 ./CAcerts/*.crt); do
   CA_ISSUER=$(openssl x509 -in $nome_crt -noout -issuer | awk -F "CN = " '{print $2}')
   SUBJECT=$(openssl x509 -in $i -noout -subject | awk -F "CN = " '{print $2}')
   if [ "$ISSUER" = "$SUBJECT" ]; then
      cp $i ./cadeia_certs
      ISSUER=$(openssl x509 -in $i -noout -issuer | awk -F "CN = " '{print $2}')      
      CA_ISSUER=$(openssl x509 -in $i -noout -issuer | awk -F "CN = " '{print $2}')      
      if [ "$CA_ISSUER" = "$SUBJECT" ]; then
         flag_raiz=1
         break
      else
         break
      fi
   fi
done
}

search_privkey(){
echo "Procurando chave privada (.key) na pasta local..."
if [ $(ls -1 *.key 2>/dev/null | wc -l) -eq 1 ]; then
   nome_key=$(ls -1 *.key)
else
   echo "Procurando chave privada (.key) no apache..."
   if [ $(ls -1 /etc/httpd/conf/ssl.key/*.key 2>/dev/null | wc -l) -eq 1 ]; then
      nome_key=$(ls -1 /etc/httpd/conf/ssl.key/*.key)
   fi
   if [ $(ls -1 /etc/httpd/ssl/*.key 2>/dev/null | wc -l) -eq 1 ]; then
      nome_key=$(ls -1 /etc/httpd/ssl/*.key)
   fi
   if [ $(ls -1 /etc/pki/tls/certs/*.key 2>/dev/null | wc -l) -eq 1 ]; then
      nome_key=$(ls -1 /etc/pki/tls/certs/*.key)
   fi
fi
}

URL=$(ENV=$(find ./gerid-sigepe -maxdepth 2 -name "env.xml" | head -n 1) ; grep -i authn.cas.service $ENV  |awk -F '/' '{print $3}')

search_cert(){
echo "Procurando certificado ($URL.crt) na pasta local..."
if [ $(ls -1 *.crt 2>/dev/null | wc -l) -eq 1 ]; then
   nome_crt=$(ls -1 *.crt)
else
   echo "Procurando certificado (.crt) no apache..."
   if [ $(ls -1 /etc/httpd/conf/ssl.crt/*.crt 2>/dev/null | wc -l) -eq 1 ]; then
      nome_crt=$(ls -1 /etc/httpd/conf/ssl.crt/*.crt)
   fi
   if [ $(ls -1 /etc/httpd/ssl/*.crt 2>/dev/null | wc -l) -eq 1 ]; then
      nome_crt=$(ls -1 /etc/httpd/ssl/*.crt)
   fi
   if [ $(ls -1 /etc/pki/tls/certs/*.crt 2>/dev/null | wc -l) -eq 1 ]; then
      nome_crt=$(ls -1 /etc/pki/tls/certs/*.crt)
   fi
fi
}



echo
echo
echo
echo
echo "                          GERADOR DE KEYSTORE"
echo
echo "AVISO: Este script usa arquivos .crt e .key para construir keystore.jks."
echo "       Obrigatoria a existencia dos certificados na pasta ./CAcerts"
echo "-----------------------------------------------------------------------------"
IFS=$'\n'
cp CAcerts/ImportKey.class .
if [ ! -s ImportKey.class ]; then
   importkey=$(locate ImportKey.class | head -1)
   if [ $importkey ]; then
      cp $importkey . 2>/dev/null
      echo "Utilizando ImportKey.class"
   elif [ $(ls ImportKey.class) ]; then
      echo "Utilizando ImportKey.class"
   else
      echo "Favor disponibilizar na pasta corrente o arquivo ImportKey.class"
      echo "Operação abortada"
      exit 1
   fi
fi


# CHAVE PRIVADA
search_privkey

if [ $nome_key ]; then
   echo "    Chave privada encontrada: $nome_key"
   openssl pkcs8 -topk8 -nocrypt -in $nome_key -inform PEM -out ${nome_key}.der -outform DER
else
   echo "    Chave privada não encontrada ou há mais de uma chave nas pastas pesquisadas"
   echo
   ls -1 /etc/httpd/conf/ssl.key/*.key /etc/httpd/ssl/*.key
   echo
   echo -n "Informe o caminho/nome completo do .key ou ENTER para aceitar [$nome_key]: "
   read resp
   if [ $resp ]; then
      nome_key="$resp"
      openssl pkcs8 -topk8 -nocrypt -in $nome_key -inform PEM -out ${nome_key}.der -outform DER
   fi
fi


# CHAVE PUBLICA E CADEIA
search_cert

if [ $nome_crt ]; then
   echo "    Certificado encontrado: $nome_crt"
   openssl x509 -in $nome_crt -inform PEM -out ${nome_crt}.der -outform DER    
   ISSUER=$(openssl x509 -in $nome_crt -noout -issuer | awk -F "CN = " '{print $2}')
   rm -rf ./cadeia_certs
   mkdir -p ./cadeia_certs
   flag_raiz=0
   qtd=1
   while [ "$flag_raiz" -eq 0 -a "$qtd" -lt 5 ]; do
      search_issuer
      let qtd++
   done
   if [ "$(ls -1 ./cadeia_certs/*.crt | wc -l)" -lt 2 ]; then
      echo "A quantidade de certificados encontrados para montar a cadeia se encontra abaixo do esperado."
      echo "O certificado assinante de um dos certificados abaixo nao foi encontrado. Favor verificar."
      echo
      ls -1 ./cadeia_certs/*.crt
      echo
      echo "Operacao abortada!"
      exit 1
   else
      for i in $(ls -1 ./cadeia_certs/*.crt); do
         openssl x509 -in $i -inform PEM -out $i.der -outform DER
      done
      cat ${nome_crt}.der ./cadeia_certs/*.der > cadeia.der
      echo
      echo -n "Informe alias para o certificado principal: "
      #read nome_alias
      #nome_alias=$(grep -i authn.keystore.key.alias.signature env.xml | awk -F '"' '{print $4}')
      for i in $(find ./gerid-sigepe -maxdepth 2 -name "env.xml"); do
    #                    nome_alias=$(grep -i authn.keystore.key.alias.signature env.xml | awk -F '"' '{print $4}') > /dev/null
      URL=$(ENV=$(find ./gerid-sigepe -maxdepth 2 -name "env.xml" | head -n 1) ; grep -i authn.cas.service $ENV  |awk -F '/' '{print $3}')
      ALIAS=$(ENV=$(find ./gerid-sigepe -maxdepth 2 -name "env.xml" | head -n 1) ; grep -i authn.keystore.key.alias.signature $ENV  |awk -F '"' '{print $4}') > /dev/null
                        if [ $URL = ${nome_crt} ]; then
                              echo ALIAS="$ALIAS"
                        else
                                ALIAS="$i"
                                ALIASINCORRETO="sim"
                                echo -n "Certificado cliente indevido em ${i}: "
                                $(locate keytool | grep "bin/keytool$" | grep -v "java-1.4.2" | tail -1) -list -storepass "/dataprev*1" -keystore ${i} -v | grep "Alias name:"
                                echo
                                echo "Nova keystore deve ser gerada com o certificado correto."
                        fi
      done
      #nome_alias=$(grep -i authn.keystore.key.alias.signature $ALIAS | awk -F '"' '{print $4}')
#      echo -n "Digite a senha da keystore: "
#      read senha_keystore
#      $(locate java | grep "bin/java$" | tail -1) ImportKey ${nome_key}.der cadeia.der ${nome_alias} keystore.jks -storepasswd ${senha_keystore}
      $(locate java | grep "bin/java$" | grep -v "java-1.4.2" | tail -1) ImportKey ${nome_key}.der cadeia.der ${ALIAS} keystore.jks
   fi
else
   echo "Certificado nao encontrado ou existe mais de um certificado nas pastas pesquisadas"
   echo
   ls -1 /etc/httpd/conf/ssl.crt/*.crt /etc/httpd/ssl/*.crt
   echo
   echo -n "Informe o caminho/nome completo do .crt ou ENTER para aceitar [$nome_crt]: "
   read resp
   if [ $resp ]; then
      nome_crt="$resp"
      openssl x509 -in $nome_crt -inform PEM -out ${nome_crt}.der -outform DER    
      ISSUER=$(openssl x509 -in $nome_crt -noout -issuer | awk -F "CN = " '{print $2}')
      rm -rf ./cadeia_certs
      mkdir -p ./cadeia_certs
      flag_raiz=0
      qtd=1
      while [ "$flag_raiz" -eq 0 -a "$qtd" -lt 5 ]; do
         search_issuer
         let qtd++
      done
      if [ "$(ls -1 ./cadeia_certs/*.crt | wc -l)" -lt 2 ]; then
         echo "A quantidade de certificados encontrados para montar a cadeia se encontra abaixo do esperado."
         echo "O certificado assinante de um dos certificados abaixo nao foi encontrado. Favor verificar."
         ls -1 ./cadeia_certs/*.crt
         echo "Operacao abortada!"
         exit 1
      else
         for i in $(ls -1 ./cadeia_certs/*.crt); do
            openssl x509 -in $i -inform PEM -out $i.der -outform DER
         done
         cat ${nome_crt}.der ./cadeia_certs/*.der > cadeia.der
         echo -n "Informe alias para o certificado principal: "
         read nome_alias
#         echo -n "Digite a senha da keystore: "
#         read senha_keystore
#         $(locate java | grep "bin/java$" | tail -1) ImportKey ${nome_key}.der cadeia.der ${nome_alias} keystore.jks -storepasswd ${senha_keystore}
         $(locate java | grep "bin/java$" | grep -v "java-1.4.2" | tail -1) ImportKey ${nome_key}.der cadeia.der ${nome_alias} keystore.jks
      fi
   fi
fi

#rm -f ImportKey.class

echo
echo
echo
$(locate keytool | grep "bin/keytool$" | grep -v "java-1.4.2" | tail -1) -noprompt -keypasswd -alias ${nome_alias} -keypass "changeit" -new "/dataprev*1" -storepass "changeit" -keystore keystore.jks
$(locate keytool | grep "bin/keytool$" | grep -v "java-1.4.2" | tail -1) -noprompt -storepasswd -new "/dataprev*1" -storepass "changeit" -keystore keystore.jks
#echo -n "Deseja alterar a senha da keystore? (s/n): "; read RESP
#case $RESP in 
#   s|S) echo "Alterando senha da chave privada..." ;
#        $(locate keytool | grep "bin/keytool$" | grep -v "java-1.4.2" | tail -1) -keypasswd -alias ${nome_alias} -keystore keystore.jks ;
#        echo "Alterando senha da base de chaves..." ;
#        $(locate keytool | grep "bin/keytool$" | grep -v "java-1.4.2" | tail -1) -storepasswd -keystore keystore.jks ;;
#   *) ;;
#esac

