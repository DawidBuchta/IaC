Do poprawnego działania należy stworzyć 2 pliki z wartościami wrażliwymi.

1. secrets.auto.tfvars -- z przykładową zawartością:

admin_username = "admin"

admin_password = "password"

2. plik w folderze VM o nazwie secrets.yml -- z przykładową zawartością:

ansible_user: .\admin

ansible_password: "password"

dsrm_password: "dsrm#password"

sa_password: "haslo_bazy_danych"