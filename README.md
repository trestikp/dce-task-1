# KIV/DCE úkol 1
## Návod k použití
#### předpoklady
* vycházíme z IaC devcontaineru, který nám byl poskytnut (máme tedy terraform, ansible a další zvávislosti)
* fungují linuxové symbolické linky (automaticky splněno použitím IaC devcontaineru)
    * Ansible používá symbolické linky na adresáře aplikace (demo-3)
    * snaha předejít absolutním cestám a zamezit tak nutnosti uprovavovat cesty, pokud by projekt byl umístěn na jiné absolutní cestě
* .ssh/known_hosts nemá záznamy pro IP adresy přiřazené vytvořeným nodům
* vytvořené nody používají existující OS image - KIV-DCE Ubuntu 22.04 (ID: 422)

#### spuštění
1. použití vlastních přístupových údajů v souboru **terraform.tfvars**
1. ```terraform init```
1. (RECOMMENDED, OPTIONAL) ```terraform plan```
1. ```terraform apply -auto-approve```

#### dodatečné příkazy
* manuální spuštění ansible (instalace aplikace na vytvořené nody). Spuštění je součástí terraformu a nemělo by být nutné tento krok provádět manuálně.
    * ```ansible-playbook -T 30 -i dynamic_inventories/semestral_task ansible/semestral-task.yml```

## Poznámky k modifikácím demo-3 aplikace
* v backendu přibyl "run_server.sh", pro spouštění app serveru pomocí pythonu
    * POZOR! pouze pro naše/ vývojové účely. Spuštění do produkce se běžné dělá pomocí WSGI serverů (např. gunicorn)
    * server je pouštěn na přímo ve VM (nodu) a né pomocí dockeru
        * build docker image na jednotlivých nodech není vhodné řešení
        * distribuce docker image, který je vytvořen na host stroji je možná, ale protože pracujeme v docker kontajneru, tak je obtižné spustit docker image build, kvůli Docker-in-Docker problému
* na frontendu vznikly následující zmněny
    * config/demo-server - nový soubor. Nastavení nginx serveru jako reverse-proxy (load balancer) pro Ubuntu
    * backend-upstream.conf - soubor neexistuje, protože je generovaný z šablony, podle toho, jaké adresy jsou přiřazeny backend nodům
    * backend-upstream.conf.tmpl - šablona, podle které se vygeneruje soubor **backend-upstream.conf**
