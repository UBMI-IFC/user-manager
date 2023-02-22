#! /usr/bin/bash

# Manejador de usuarios para cursos de la UBMI
# CPA 2022



########## Funciones ########################################################################
#mensaje de ayuda
Help()
{
    echo
    echo "                                ${colorbg}UBMI  USER  MANAGER${reset}                " 
    echo
    echo "${info}Uso:${reset}"                                                                  
    echo "    ${error}$sudo ./user_manager.sh [-ecgs] [-r user@ip] [-n nombre_del_grupo] -i archivo.csv${reset}"
    echo
    echo "${warn}TL;DR"
    echo
    echo "Crea usuarios a partir de lista creando único grupo 'padre'"
    echo "    ${error}$sudo ./user_manager.sh -c -g -n nombre_grupo -i archivo.csv"
    echo
    echo "${warn}Elimina usuarios y su grupo 'padre' si este queda vacío"
    echo "    ${error}$sudo ./user_manager.sh -e -g -i archivo.csv" 
    echo
    echo "${info}Argumentos:"
    echo
    echo "${warn}-i ----- Especifica un archivo de entrada, se requiere un archivo separado por comas"
    echo "          con el siguiente formato:"
    echo "          Nombre, e-mail, grupo al que pertenece (GID), ID de usuario, nombre de usuario"
    echo "          ${error}Ejemplo:"
    echo "          Ángel Rodriguez,arodriguez@ifc.unam.mx,9900,9924,arodriguez9900${warn}"
    echo
    echo "-e ----- Elimina a los usuarios del archivo de entrada, incluyendo sus carpetas en /home"
    echo
    echo "-c ----- Crea a los usuarios del archivo de entrada"
    echo
    echo "-g ----- Extiende operación al grupo 'padre' si se usa con -e elimina al grupo 'padre'"
    echo "          si este no tiene mas usuarios, si se usa con -c crea al grupo 'padre'"
    echo
    echo "-n ----- Si se usa -c y -g esta opción permite asignar un nombre al grupo 'padre' creado"
    echo "          si se omite este argumento, se preguntará interactivamente el (los) nombre(s)"
    echo "          ${error}NO usar si se va a crear mas de un grupo${warn}"
    echo
    echo "-s ----- usado con -e evita la destrucción de la carpeta /home"
    echo
    echo "-r ----- Checa si los usuarios y grupos del archivo de entrada existen en servidor remoto"
    echo "          requiere credenciales SSH al servidor objetivo${reset}"
    echo
}

# Main function
userManager()
{
    echo
    echo "                             ${colorbg}UBMI  USER  MANAGER${reset}                       " 
    echo

    tablecheck

    if [ $remserv != "_NONE_" ];
    then
	checkInServer $remserv
    fi

    if [ $eliminar = true ];
    then
	deleteUsers $salvar
	deleteGroups $grupo
    fi

    if [ $crear = true ];
    then
	createGroupAndUsers $grupo $nomgru
    fi  
}

filterByGiD()
{
    grep -E ,$1,[0-9] $2
}

createUsers()
{
    while read line
    do
	hname=$(echo $line | cut -f 1  -d ',')
	mail=$(echo $line | cut -f 2 -d ',')
	gid=$(echo $line | cut -f 3 -d ',')
	uid=$(echo $line | cut -f 4 -d ',')
	uname=$(echo $line | cut -f 5 -d ',')

	uexist=$(grep $uname: /etc/passwd | wc -l ) 

	if [ $uexist == "0" ]; then
	    echo "${info}INFO: Intentando crear usuario $uname . . . ${reset}"
	    useradd -u "$uid" -G "$gid" -m -s "/bin/bash" -c "$hname,,$mail," "$uname" ||  echo "${warn}ADVERTENCIA: Intentando crear en modo jefe de grupo . . . ${reset}" && useradd -u "$uid" -g "$gid" -m -s "/bin/bash" -c "$hname,,$mail," "$uname"
	    uspas=$uname:$(tr -dc A-Za-z0-9 </dev/urandom | head -c 6 ; echo '')
	    echo $uspas | chpasswd -m
	    echo $line,$uspas >> new_users.ubmi
	    echo

	else
	    echo "${error}ERROR: Ya existe un usuario con nombre $uname"
	    echo "${warn}ADVERTENCIA: no se creará este usuario pero se guardará en ${colorbg}fail_users.ubmi${reset}"
	    echo
	    echo $line >> fail_users.ubmi
	fi

    done < $1

}

createGroups()
{
    groupadd -g $1 $2
}

createGroupAndUsers()
{
    echo "#$(date)" > new_users.ubmi
    echo "#$(date)" > fail_users.ubmi
    
    if [ $1 = true ];
    then
	local numgru=$(cat $inputfile | cut -f 3 -d ',' | sort | uniq | wc -l)

	if [ $numgru == "1" ];
	then
	    if [ $nomgru == "_NONE_" ]; then
		read tryname
		local verifnomgru=$( grep $tryname /etc/group/ | wc -l)
		if [ $tryname != "0" ]; then
		    echo "${error}ERROR: Nombre de grupo ya existente, terminando proceso${reset}"
		    echo
		else
		    nomgru=$tryname
		fi
	    else
		echo "${info}INFO: Verificando información para crear grupo $nomgru . . ."
	    fi
	    
	    local gid=$(cat $inputfile | cut -f 3 -d ',' | sort | uniq)
	    local checkedg=$(grep $gid /etc/group | wc -l)
	    if [ $checkedg != "0" ]; then
		local gnombre=$(grep $gid /etc/group | grep -Eo '^[A-Za-z0-9_-]+')
		echo
		echo "${warn}ADVERTENCIA: Grupo $gid ya  existe con el nombre $gnombre, no se creará . . ."
	        echo "¿Quieres continuar creando a los usuarios agregandolos a ese grupo? (y / n)${reset}"
		echo
		read contp
		if [ $contp == "y" ]; then
		    createUsers $inputfile
		else
		    echo "${warn} NO SE CREARON USUARIOS ... TERMINANDO${reset}"
		    echo
		    exit
		fi
				
	    else
		echo "${info}INFO: El grupo $gid se creará con el nombre $nomgru ${reset} . . ."
		echo
		createGroups $gid $nomgru
		echo "${info}INFO: Intentando crear usuarios . . .${reset}"
		echo
		createUsers $inputfile
	    fi
	        
	elif [ $numgru != "1" ] && [ $numgru != "0"];
	then
	    local gid2check=$(cat $inputfile | cut -f 3 -d ',' | sort | uniq)
	    for g in $gid2check
	    do
		local checkedg=$(grep $g /etc/group | wc -l)
		if [ $checkedg != "0" ]; then
		    local gnombre=$(grep $g /etc/group | grep -Eo '^[A-Za-z0-9_-]+')
		    echo "${error}ERROR: Grupo $g existe con el nombre $gnombre, ¿Quieres asignar usuarios a grupo existente? (y / n) . . .${reset}"
		    read conti
		    if [ conti == "y" ]; then
			echo "${warn}ADVERTENCIA: Se crearán usuarios del grupo $g en el grupo previamente existente . . . ${reset}"
			filterByGiD $g $inputfile > tmp_gfile.csv
		        createUsers tmp_gfile.csv
		        rm tmp_gfile.csv
		    else
			echo "${error}ERROR: No se crearon usuarios del grupo $g ${reset}"
		    fi
		    
		else
		    echo "${info}INFO: El grupo $g no existe aún, intentando crear ... ${reset}"
		    echo "${info}INFO: Introduce un nombre para grupo $g ${reset}"
		    read tmpname
		    retryname=true
		    while [ $retryname ]; do
			local checkgname=$(grep $tmpname /etc/group | wc  -l)
			if [ $checkgname == "0" ]; then
			    echo "${info}INFO: Nombre disponible, creando grupo $tmpname . . . ${reset}"
			    createGroups $g $tmpname
			    echo "${info}INFO: Creando usuarios asociados al grupo $tmpname . . . ${reset}"
			    echo
			    filterByGiD $g $inputfile > tmp_gfile.csv
		            createUsers tmp_gfile.csv
		            rm tmp_gfile.csv
			    retryname=false
			else
			    echo "${error}ERROR: Nombre no disponible, intenta otro nombre o termina el programa con ${reset} ${colorbg}Ctrl+c${reset}"
			    echo
			    echo "${warn} Introduce un nombre para grupo $g ${reset}"
			    read tmpname
			    echo
			fi
		    done
		fi
	    done
	else
	    echo "${error}ERROR: numero de grupos no reconocido, revisa datos de entrada${reset}"
	fi
    elif : [ $1 = false ];
    then
	local gid2check=$(cat $inputfile | cut -f 3 -d ',' | sort | uniq)
	for g in $gid2check
	do
	    local checkedg=$(grep $g /etc/group | wc -l)
	    if [ $checkedg != "0" ]; then
		local gnombre=$(grep $g /etc/group | grep -Eo '^[A-Za-z0-9_-]+')
		echo "${info}INFO: Grupo $g existe con el nombre $gnombre, creando y agregando usuarios al grupo . . .${reset}"
		filterByGiD $g $inputfile > tmp_gfile.csv
		createUsers tmp_gfile.csv
		rm tmp_gfile.csv
	    else
		echo "${error}ERROR: El grupo $g no existe, no se crearan usuarios asociados a dicho grupo${reset}"
	    fi
	done	
    fi
}


# verificación de archivo
tablecheck()
{
    tstfilecomp=$(cat $inputfile | egrep  "^[a-z A-ZáéíóúñÑÁÉÍÓÚ]+,[a-z._0-9]+@[a-z._0-9]+,[0-9]{4},[0-9]{4},[a-z0-9]+$" | wc -l)
    tstfilelen=$(cat $inputfile | wc -l)
    if [ $tstfilecomp == "0" ];
    then
	echo
	echo "${error}ERROR:"
	echo "Archivo en un formato diferente al requerido"
	echo "usa -h para ver formato${reset}"
	echo
	exit
    elif [ "$tstfilecomp" != "$tstfilelen" ];
    then
	echo
	echo "${warn}ADVERTENCIA:"
	echo "Al menos uno de los renglones del archivo tiene un problema de formato:"
	echo "Renglones con formato correcto: $tstfilecomp / $tstfilelen"
	echo
	echo "Renglones problemáticos:${error}"
	cat $inputfile | egrep  -v  "^[a-z A-ZáéíóúñÑÁÉÍÓÚ]+,[a-z._0-9]+@[a-z._0-9]+,[0-9]{4},[0-9]{4},[a-z0-9]+$"
	echo
	echo "${warn}NO se procesaran los renglones problematicos."
	echo "${error}Deseas continuar? (y / n)${reset}"
	read cont
	if [ "$cont" == "y" ] || [ "$cont" == "Y" ];
	then
	    cat $inputfile | egrep "^[a-z A-ZáéíóúñÑÁÉÍÓÚ]+,[a-z._0-9]+@[a-z._0-9]+,[0-9]{4},[0-9]{4},[a-z0-9]+$" > filteredinput.csv
	    inputfile=filteredinput.csv
	else
	    exit
	fi
    fi
}

# Delete users
deleteUsers()
{
    echo "${info}Eliminando usuarios . . .${reset}"
    while read line
    do
	uname=$(echo $line | cut -f 5 -d ',')
	userdel $1 $uname   
    done < $inputfile
}

# remote verification of groups and users
checkInServer()
{
    local rgroups=$(cat $inputfile | cut -f 3 -d ','| sort | uniq)
    local ruid=$(cat $inputfile | cut -f 4 -d ',')
    local runame=$(cat $inputfile | cut -f 5 -d ',')
    local ask=false
    echo
    echo "${info}Revisando grupos en el servidor remoto ...${reset}"
    echo
    
    for g in $rgroups
    do
	local cgroup=$(ssh $1 cat /etc/group | grep $g | grep -Eo "^[A-Za-z0-9]+" | wc -l)
	if [ $cgroup == "0" ];
	then
	    echo "${info}El grupo $g no existe en $1 ${reset}"
	else
	    local ngroup=$(ssh $1 cat /etc/group | grep $g | grep -Eo "^[A-Za-z0-9]+")
	    echo "${warn}El grupo $g existe en $1 con el nombre $ngroup ${reset}"
	    local ask=true
	fi
    done
    
    echo "${info}Revisando IDs de usuarios en el servidor remoto ...${reset}"
    echo
    echo "tmpfile" > tmpuid.txt
    
    for i in $ruid
    do
	local cuid=$(ssh ifc cat /etc/passwd | grep $i | wc -l)
	if [ $cuid != "0" ];
	then
	    ssh ifc cat /etc/passwd | grep $i >> tmpuid.txt
	fi
    done
    
    local lencheck0=$(wc -l tmpuid.txt| cut -f 1 -d ' ')
    
    if [ $lencheck0 != "1" ];
    then
	echo "${warn}INFO: Estos usuarios ya existen en $1:"
	echo
	cat tmpuid.txt
	echo "${reset}"
	rm tmpuid.txt
	local ask=true
    else
	echo "${info}No existen usuarios en $1 con los IDs del archivo de entrada :D${reset}"
	echo
	rm tmpuid.txt
    fi
    echo
    echo "${info}Revisando nombres de usuarios en el servidor remoto ...${reset}"
    echo
    echo "tmpfile" > tmpuname.txt
    for i in $runame
    do
	local cuname=$(ssh ifc cat /etc/passwd | grep $i | wc -l)
	if [ $cuname != "0" ];
	then
	    ssh ifc cat /etc/passwd | grep $i >> tmpuname.txt
	fi
    done

    local lencheck=$(wc -l tmpuname.txt| cut -f 1 -d ' ')
    
    if [ $lencheck != "1" ];
    then
	echo "${warn}INFO: Estos usuarios ya existen en $1:${reset}"
	echo
	cat tmpuname.txt
	echo
	rm tmpuname.txt
	local ask=true
    else
	echo "${info}No existen usuarios en $1 con los nombres del archivo de entrada :D${reset}"
	echo
	rm tmpuname.txt
    fi

    if [ $ask == true ];
    then
        echo "${error}Deseas continuar? (y / n)${reset}"
	read cont
	if [ "$cont" == "y" ] || [ "$cont" == "Y" ];
	then
	    echo
	    echo ":D "
	    echo
	else
	    exit
	fi
    fi
}

#remove groups
deleteGroups()
{
    if [ $1 == true ];
    then
	local tablegroups=$(cat $inputfile | cut -f 3 -d ',' | sort | uniq)

	for g in $tablegroups
	do
	    local emptyg=$(grep ":$g:" /etc/group  | grep -Eo ':[A-Za-z0-9_]+$'| wc -l)
	    local nouser=$(grep "$g" /etc/passwd | wc -l)
	    local gname=$(grep ":$g:" /etc/group | grep -Eo '^[A-Za-z0-9_]+')
	    
			      if [ $emptyg == "0" ] && [ $nouser == "0" ];
			      then
				  echo "${info}INFO: Eliminando grupo $g $gname ...${reset}"
				  groupdel "$gname"
			      elif [ $emptyg != "0" ];
			      then
				  echo "${error}ERROR: El grupo $g $gname tiene usuarios asociados: no se eliminará${reset}"
			      else
				  echo "${error}ERROR: El grupo $g $gname es el grupo de un usuario: no se eliminará${reset}"
			      fi
	done
    else
	echo "${info}INFO: No se eliminarán grupos${reset}"
	echo
    fi	  
}



########### Revisa argumentos #################################################################

# Colores para texto
error=`tput setaf 1`
info=`tput setaf 2`
warn=`tput setaf 3`
colorbg=`tput setab 1`
reset=`tput sgr0`


if [ $# -lt 1 ];
then
    Help
    exit
fi

eliminar=false
crear=false
grupo=false
salvar="-r"
remserv="_NONE_"
nomgru="_NONE_"

while getopts i:hecgsr:n: flag
do
    case $flag in
        h) Help
	   exit;;
	i) inputfile=$OPTARG;;
	e) eliminar=true;;
	c) crear=true;;
	g) grupo=true;;
	s) salvar="";;
	r) remserv=$OPTARG;;
	n) nomgru=$OPTARG;;
	*) echo
	   echo "${error}ERROR: Usa -h para ver ayuda${reset}"
	   echo
	   exit;;
    esac
done

if [ ! "$inputfile" ];
then
  echo  
  echo "${error}ERROR: Archivo de entrada faltante, opción -i, revisa uso y opciones con -h${reset}"
  echo
  exit 
fi

if [ $crear == true ] && [ $eliminar == true ];
then
    echo
    echo "${error}ERROR: Opciones -c y -e seleccionadas simultaneamente${reset}"
    echo
    exit
fi

############# Lanza programa XP #######################################################################

userManager

