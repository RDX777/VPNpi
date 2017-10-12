#!/bin/bash

clear
echo "Script para configuração de VPN Raspberry"
echo ""

Instalado=$(dpkg -l | grep pptpd | awk '{print substr($0, 1, 2)}')
if [ "$Instalado" = "ii" ]
then
	echo "O PPTPD já esta instalado, apenas conclua a configuração."
	echo ""
	sudo cp /etc/ppp/chap-secrets_pptpd_Original /etc/ppp/chap-secrets
	sudo cp /etc/pptpd_pptpd_Original.conf /etc/pptpd.conf
	sudo cp /etc/ppp/pptpd-options_pptpd_Original /etc/ppp/pptpd-options
	sudo cp /etc/sysctl_pptpd_Original.conf /etc/sysctl.conf
	sudo cp /etc/rc.local_pptpd_Original /etc/rc.local
else
	echo "NECESSARIO CONEXÃO COM A INTERNET"
	echo ""
	echo ""	
	echo "O PPTPD não esta instalado, realizando instalação. Por favor Aguarde..."
	echo ""
	sudo apt-get update && sudo apt-get install pptpd -y --fix-missing
	if [ ! -f /etc/ppp/chap-secrets_pptpd_Original ]
	then
		sudo cp /etc/ppp/chap-secrets /etc/ppp/chap-secrets_pptpd_Original
	fi
	if [ ! -f /etc/pptpd_pptpd_Original.conf ]
	then
		sudo cp /etc/pptpd.conf /etc/pptpd_pptpd_Original.conf
	fi
	if [ ! -f /etc/ppp/pptpd-options_pptpd_Original ]
	then
		sudo cp /etc/ppp/pptpd-options /etc/ppp/pptpd-options_pptpd_Original
	fi
	if [ ! -f /etc/sysctl_pptpd_Original.conf ]
	then
		sudo cp /etc/sysctl.conf /etc/sysctl_pptpd_Original.conf
	fi
	if [ ! -f /etc/rc.local_pptpd_Original ]
	then
		sudo cp /etc/rc.local /etc/rc.local_pptpd_Original
	fi	
fi

echo ""
echo "Configuração inicial da VPN."
echo ""

echo "Digite os dados solicitados abaixo:"
echo "IP Local Do raspberry:"
echo "Em branco = 10.0.0.103"
read IpLocal
	if [ -z $IpLocal ] 
	then
		IpLocal=10.0.0.103
	fi

echo "IP Remoto, usado nos clientes:"
echo "Em branco = 192.168.125.1-254"
read IpRemoto
	if [ -z $IpRemoto ]
	then
		IpRemoto=192.168.125.1-254
	fi

echo "Servidor DNS"
echo "Em branco = 10.0.0.1"
read ServidorDNS
	if [ -z $ServidorDNS ]
	then
		ServidorDNS=10.0.0.1
	fi

echo "Deseja habilitar o encaminhamento de rede para os IPs $IpRemoto?"
echo "Sim = s ou Não = n | Em branco = Não"
read EncaminhamentoRedeRemoto
	if [ "$EncaminhamentoRedeRemoto" = "s" ] || [ "$EncaminhamentoRedeRemoto" = "S" ]
	then
		EncaminhamentoRedeRemoto="1"
	else
		EncaminhamentoRedeRemoto="0"
	fi

echo "Deseja habilitar o encaminhamento de rede, para os micros da rede LAN?"
echo "Sim = s ou Não = n | Em branco = Não"
read EncaminhamentoRedeLAN
	if [ "$EncaminhamentoRedeLAN" = "s" ] || [ "$EncaminhamentoRedeLAN" = "S" ]
	then
		echo "Digite a interface conectada a sua rede interna:"
		echo "1 = eth0 ou 2 = wlan0"
		read InterfaceInterna
		if [ "$InterfaceInterna" = 1 ]
		then
			InterfaceInterna="eth0"
		else
			InterfaceInterna="wlan0"
		fi
	fi

sudo echo "" >> /etc/pptpd.conf
sudo echo "localip $IpLocal" >> /etc/pptpd.conf
sudo echo "remoteip $IpRemoto" >> /etc/pptpd.conf
sudo echo "" >> /etc/ppp/pptpd-options
sudo echo "ms-dns $ServidorDNS" >> /etc/ppp/pptpd-options
sudo echo "nobsdcomp" >> /etc/ppp/pptpd-options
sudo echo "noipx" >> /etc/ppp/pptpd-options
sudo echo "mtu 1490" >> /etc/ppp/pptpd-options
sudo echo "mru 1490" >> /etc/ppp/pptpd-options
sudo echo "net.ipv4.ip_forward=$EncaminhamentoRedeRemoto" >> /etc/sysctl.conf

resposta="s"
while [ "$resposta" = "s" ] || [ "$resposta" = "S" ]
do
echo "Deseja cadastrar usuário?"
echo "Sim = s ou Não = n | Em branco = Não"
read resposta
if [ "$resposta" = "s" ] || [ "$resposta" = "S" ]
then
	echo ""
	echo "Digite o login:"
	read login
	echo "Digite a senha:"
	read senha
	echo "Digite o IP. Em branco = automatico"
	read IPcliente
	if [ -z $IPcliente ]
	then
		IPcliente=*
	fi
	echo -e "$login$(printf "\t")pptpd$(printf "\t")$senha$(printf "\t")$IPcliente" >> /etc/ppp/chap-secrets
fi
done

sudo sed -i -e '/^exit 0/i sudo /etc/init.d/pptpd start' /etc/rc.local
if [ "$EncaminhamentoRedeLAN" = "s" ] || [ "$EncaminhamentoRedeLAN" = "S" ]
then
	sudo iptables -t nat -A POSTROUTING -o $InterfaceInterna -j MASQUERADE
	sudo sed -i -e '/^exit 0/i sudo iptables -t nat -A POSTROUTING -o '$InterfaceInterna' -j MASQUERADE' /etc/rc.local	
fi

#clear
echo "Configuração concluida!"
echo "Reiniciando PPTPD..."
sudo /etc/init.d/pptpd restart
