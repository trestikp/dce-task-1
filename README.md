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
1. vyplnění vlastních přístupových údajů v souboru **terraform.tfvars**
1. ```terraform init```
1. (RECOMMENDED, OPTIONAL) ```terraform plan```
1. ```terraform apply -auto-approve```

#### dodatečné příkazy
* manuální spuštění ansible (instalace aplikace na vytvořené nody). Spuštění je součástí terraformu a nemělo by být nutné tento krok provádět manuálně.
    * ```ansible-playbook -T 30 -i dynamic_inventories/semestral_task ansible/semestral-task.yml```

## [Poznámky k modifikácím demo-3 aplikace](#demo_modifications)
* v backendu přibyl "run_server.sh", pro spouštění app serveru pomocí pythonu
    * POZOR! pouze pro naše/ vývojové účely. Spuštění do produkce se běžné dělá pomocí WSGI serverů (např. gunicorn)
    * server je pouštěn na přímo ve VM (nodu) a né pomocí dockeru
        * build docker image na jednotlivých nodech není vhodné řešení
        * distribuce docker image, který je vytvořen na host stroji je možná, ale protože pracujeme v docker kontajneru, tak je obtižné spustit docker image build, kvůli Docker-in-Docker problému
* na frontendu vznikly následující zmněny
    * config/demo-server - nový soubor. Nastavení nginx serveru jako reverse-proxy (load balancer) pro Ubuntu
    * backend-upstream.conf - soubor neexistuje, protože je generovaný z šablony, podle toho, jaké adresy jsou přiřazeny backend nodům
    * backend-upstream.conf.tmpl - šablona, podle které se vygeneruje soubor **backend-upstream.conf**

## Pozmáky k práci
* dynamický počet backendů -> mělo by stačit zvýšit počet nodů v **tfvars**
* upravená demo aplikace viz sekce [demo-3 modifikace](#demo_modifications)
* pokus o optimalizaci rychlosti deploymentu
    * např. aktualizace OS volaná v init-scriptech mohla deploy prodloužit i na více jak 1 hodinu
    * příkladová aplikace využívala Docker, ovšem tato práce Docker nepouživá, kvůli rychlejšímu nasazení (Docker image není builděn na instancích, build na hostu narazí na Docker-in-Docker problém)
* pokus o maximální automatizaci procesu - je potřeba manuálně vyplnit přihlašovací údaje v **tfvars**, poté je spouštění možné dvěma příkazy
* práce je založena na MicroK8s cvičení

## Konečný testovací scénář

```
host: podman run -it --rm --entrypoint=/bin/bash iac-development-container:latest

container history:
    1  ls
    2  git clone https://github.com/trestikp/dce-task-1.git
    3  ls
    4  cd dce-task-1/
    5  ls
    6  vim terraform.tfvars 
    7  apt install vim
    8  apt update
    9  apt install vim
   10  vim terraform.tfvars 
   11  cat /var/iac-dev-container-data/id_ecdsa.pub 
   12  vim terraform.tfvars 
   13  terraform init
   14  terraform apply -auto-approve
   15  history
```

Po dokončení ```terraform apply``` jsou do konzole vypsány IP adresy nodů. Zkopírování frontend-node
adresy a její vložení do prohlížeče zobrazí defaultní statické HTML. Po zadání URL {ip}/service-api/find/echo se zobrazi dynamicky generovaný obsah, který má na spodku stránky informaci o tom, který backend obsah poskytl. Zobrazené jméno je DNS jméno serveru, tedy např. **Served by: sulis94.zcu.cz** (poskytnuto backendem s IP: 147.228.173.94).