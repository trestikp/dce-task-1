# KIV/DCE úkol 1
## Návod k použití
#### předpoklady
* vycházíme z IaC devcontaineru, který nám byl poskytnut (máme tedy terraform, ansible a další zvávislosti)
* projekt je umístěn na této cestě: /workspace/kiv-dce-lab-projects/dce-task-1/
    * ansible použivá aboslutní cesty k souborům aplikace (demo-3)
    * TODO: tuto se možná změní
* .ssh/known_hosts nemá záznamy pro IP adresy přiřazené vytvořeným nodům

1. terraform init
2. (RECOMMENDED, OPTIONAL) terraform plan
3. terraform apply -auto-approve

#### dodatečné příkazy
* manuální spuštění ansible (instalace aplikace na vytvořené nody)

## Poznámky k modifikácím demo-3 aplikace
* v backendu přibyl "run_server.sh", pro spouštění app serveru pomocí pythonu
    * POZOR! pouze pro naše/ vývojové účely. Puštění do produkce se běžné dělá pomocí WSGI serverů (např. gunicorn)
    * server je pouštěn na přímo ve VM (nodu) a né pomocí dockeru
        * build docker image na jednotlivých nodech není vhodné řešení
        * distribuce docker image, který je vytvořen na host stroji je možná, ale protože pracujeme v docker kontajneru, tak je obtižné spustit docker image build, kvůli Docker-in-Docker problému
* na frontendu vznikly následující zmněny
    * config/demo-server - nový soubor. Nastavení nginx serveru jako reverse-proxy (load balancer) pro Ubuntu
    * backend-upstream.conf - soubor neexistuje, protože je generovaný z šablony, podle toho, jaké adresy jsou přiřazeny backend nodům
