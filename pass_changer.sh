#! /bin/bash

toma un archivo en formato nombre:contraseña por linea y cambia el password

while read line ; do
    echo $line | chpasswd -m 
done < $1
