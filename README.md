# user-manager

Por ahora solamente está probada y funcional con las combinatorias de opciones : 
- **-c -n [nombre de usuario] -g -i [archivo.csv]**
- **-e -g -i [archivo.csv]**
- **-c -i [archivo.csv]**

Solamente se han probado con archivos con **un único grupo**

Bugs conocidos:
- no usar la opción -n con un sólo grupo ignora el nombre introducido en la CLI y le asigna el nombre /_NONE/_, que es el valor default para la variable del nombre del grupo. 
