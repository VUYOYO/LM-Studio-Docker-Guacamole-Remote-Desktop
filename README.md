# LM Studio Docker (Guacamole Remote Desktop)

Author: VUYOYO

## 1. Project Overview

This project runs LM Studio inside Docker with an XFCE desktop and provides browser remote access through Guacamole.
The XFCE desktop provides a Chrome browser for viewing documents.

![Project Preview](images/image.png)

Current architecture:

- LM Studio container: desktop, LM Studio app, x11vnc, API service (container internal port 1234)
- guacd container: Guacamole protocol proxy
- guacamole container: web access entry

Additional features of the project:

- The XFCE desktop provides a Chrome browser for viewing documents.
- Within the XFCE desktop, if LM Studio is closed, it will automatically restart.
- An HTTP standalone clipboard using UTF-8 encoding, supporting various characters including Chinese. (HTTPS required)


## 2. Host Requirements

### 2.1 Common

- Docker Engine or Docker Desktop (Compose v2)
- At least 16 GB RAM recommended
- NVIDIA GPU recommended

CUDA readiness on host is required for NVIDIA path.

### 2.2 Windows Host

- Windows 10/11
- Docker Desktop with WSL2 backend enabled
- Latest NVIDIA driver installed on host
- Docker Desktop GPU support enabled
- Host check commands:
	- `nvidia-smi` should run successfully in Windows terminal
	- `wsl -d <your-distro> nvidia-smi` should run successfully inside WSL

### 2.3 Linux Host (recommended path)

- NVIDIA driver installed and working (`nvidia-smi` available)
- NVIDIA Container Toolkit installed
- Docker daemon can run GPU containers

### 2.4 CUDA / GPU Runtime Completeness Checklist

- Driver and CUDA runtime visibility:
	- `nvidia-smi` returns GPU information without errors
	- In container, `nvidia-smi` is available (after container start)
- Docker GPU wiring:
	- `docker run --rm --gpus all nvidia/cuda:12.6.1-cudnn-devel-ubuntu22.04 nvidia-smi`
	- command should print GPU details successfully
- Optional toolkit check on host:
	- `nvcc --version` (optional for this project; not required if runtime path works)

### 2.5 Known Issues

- Based on my testing, the NVIDIA 570 driver may cause LM Studio's runtime to incorrectly display as incompatible with CUDA and Vulkan, but this does not affect actual inference capabilities.

- Based on my testing, I currently recommend upgrading to the 580 driver, as the runtime displays correctly with the 580 driver.

## 3. Configuration (.env)

Edit [.env](.env) before first run.

Important fields:

- `GUAC_WEB_PORT`: Guacamole web port on host, default `8888`
- `LMS_API_PORT`: LM Studio API port on host, default `1234`
- `GUAC_USERNAME` / `GUAC_PASSWORD`: Guacamole login account
- `GUAC_TARGET_PASSWORD`: VNC password used between Guacamole and desktop service

Critical warning:

- Do NOT change LM Studio API port in LM Studio UI.
- Container internal API is fixed to `1234`.
- If you need another host port, change only `LMS_API_PORT` in [.env](.env).

## 4. Start

This repository provides two compose modes:

- Release mode (default): `docker-compose.yml` uses image `vuyoyo/lmstudio-guacamole:latest`
- Local mode: `docker-compose.local.yml` overlays local build while keeping the same image name

Run in project root:

Release mode (default):

```bash
docker compose up -d
```

Local mode (build from local source):

```bash
docker compose -f docker-compose.yml -f docker-compose.local.yml up -d --build
```

Access URLs:

- Guacamole Web: `http://<host-ip>:<GUAC_WEB_PORT>`
- LM Studio API: `http://<host-ip>:<LMS_API_PORT>`

Default example:

- Guacamole: `http://localhost:8888`
- API: `http://localhost:1234`

## 5. Stop / Restart / Logs

```bash
# stop (release mode)
docker compose down

# stop (local mode)
docker compose -f docker-compose.yml -f docker-compose.local.yml down

# restart release mode
docker compose up -d --force-recreate

# restart local mode with rebuild
docker compose -f docker-compose.yml -f docker-compose.local.yml up -d --build --force-recreate

# logs
docker compose logs -f
docker compose logs -f lmstudio
docker compose logs -f guacamole
```

## 6. Persistent Data

The following local folders are mounted and preserved:

- `./data` -> `/app/lm-studio`
- `./cache` -> `/root/.cache/lm-studio`
- `./models` -> `/root/.cache/lm-studio/models`
- `./guacamole` -> Guacamole config and user mapping

Note for `./guacamole`:

- Connection/user-mapping content can be regenerated at startup from environment values.
- Files in this folder should be treated as a persistent reference baseline; effective runtime values may follow `.env` and `docker-compose.yml`.

## 7. Troubleshooting

### 7.1 Cannot access Guacamole page

- Check if `GUAC_WEB_PORT` is occupied
- Check firewall rules
- Check container status:

```bash
docker compose ps
```

### 7.2 GPU not available

- Verify host GPU driver and runtime
- Verify Docker GPU capability
- Check inside container logs for NVIDIA runtime detection

### 7.3 API unreachable

- Confirm `.env` value `LMS_API_PORT`
- Confirm compose mapping in [docker-compose.yml](docker-compose.yml)
- Do not change API port from LM Studio UI

## 8. AMD / Intel GPU Inference Suggestions

This project is currently optimized for NVIDIA runtime. If you want to run inference on AMD GPU or Intel GPU, use the suggestions below as a starting point.

### 8.1 Suggested direction for AMD / Intel

- Intel GPU recommendation: use Vulkan backend.
	- In [.env](.env):
		- `PREFERRED_GPU_BACKEND=vulkan`
		- `FALLBACK_GPU_BACKEND=vulkan`
	- In [docker-compose.yml](docker-compose.yml), remove NVIDIA-specific settings:
		- remove `runtime: nvidia`
		- remove `gpus: all`
		- remove `NVIDIA_VISIBLE_DEVICES` and `NVIDIA_DRIVER_CAPABILITIES`
	- Keep Vulkan userspace packages in image and verify with `vulkaninfo`.
	- For Linux host, pass `/dev/dri` into container.

- AMD GPU recommendation: prefer ROCm backend.
	- In [.env](.env), set ROCm as preferred backend if your LM Studio version exposes it:
		- `PREFERRED_GPU_BACKEND=rocm`
		- `FALLBACK_GPU_BACKEND=vulkan`
	- In [docker-compose.yml](docker-compose.yml), replace NVIDIA-specific settings:
		- remove `runtime: nvidia`
		- remove `gpus: all`
		- remove `NVIDIA_VISIBLE_DEVICES` and `NVIDIA_DRIVER_CAPABILITIES`
	- Note: `gpus: all` is NVIDIA runtime wiring and is not required by ROCm.
	- Pass ROCm-related devices into container (Linux):
		- mount `/dev/kfd`
		- mount `/dev/dri`
	- Ensure container user can access `render` and `video` groups.

### 8.2 Validation checklist

- Intel path:
	- Confirm Vulkan device is visible in container
	- Confirm LM Studio runtime backend survey can detect a Vulkan backend
- AMD path:
	- Confirm ROCm stack is visible in container (for example `rocminfo` if available)
	- Confirm LM Studio runtime backend survey can detect a ROCm backend
	- If ROCm backend is not detected, temporarily fall back to Vulkan
- Run a small model first before large-model stress tests

### 8.3 Important disclaimer

- Due to hardware limitations, I have not validated AMD GPU or Intel GPU inference in this project.
- If you require AMD/Intel production usage, you need to explore, adapt, and validate the stack on your own hardware.
kel) -
**Franziska Hinkelmann** &lt;franziska.hinkelmann@gmail.com&gt; (she/her)
* [gabrielschulhof](https://github.com/gabrielschulhof) -
**Gabriel Schulhof** &lt;gabriel.schulhof@intel.com&gt;
* [gireeshpunathil](https://github.com/gireeshpunathil) -
**Gireesh Punathil** &lt;gpunathi@in.ibm.com&gt; (he/him)
* [jasnell](https://github.com/jasnell) -
**James M Snell** &lt;jasnell@gmail.com&gt; (he/him)
* [joyeecheung](https://github.com/joyeecheung) -
**Joyee Cheung** &lt;joyeec9h3@gmail.com&gt; (she/her)
* [mcollina](https://github.com/mcollina) -
**Matteo Collina** &lt;matteo.collina@gmail.com&gt; (he/him)
* [mhdawson](https://github.com/mhdawson) -
**Michael Dawson** &lt;midawson@redhat.com&gt; (he/him)
* [mmarchini](https://github.com/mmarchini) -
**Mary Marchini** &lt;oss@mmarchini.me&gt; (she/her)
* [MylesBorins](https://github.com/MylesBorins) -
**Myles Borins** &lt;myles.borins@gmail.com&gt; (he/him)
* [targos](https://github.com/targos) -
**Michaël Zasso** &lt;targos@protonmail.com&gt; (he/him)
* [tniessen](https://github.com/tniessen) -
**Tobias Nießen** &lt;tniessen@tnie.de&gt;
* [Trott](https://github.com/Trott) -
**Rich Trott** &lt;rtrott@gmail.com&gt; (he/him)

### TSC Emeriti

* [addaleax](https://github.com/addaleax) -
**Anna Henningsen** &lt;anna@addaleax.net&gt; (she/her)
* [bnoordhuis](https://github.com/bnoordhuis) -
**Ben Noordhuis** &lt;info@bnoordhuis.nl&gt;
* [chrisdickinson](https://github.com/chrisdickinson) -
**Chris Dickinson** &lt;christopher.s.dickinson@gmail.com&gt;
* [evanlucas](https://github.com/evanlucas) -
**Evan Lucas** &lt;evanlucas@me.com&gt; (he/him)
* [Fishrock123](https://github.com/Fishrock123) -
**Jeremiah Senkpiel** &lt;fishrock123@rocketmail.com&gt; (he/they)
* [gibfahn](https://github.com/gibfahn) -
**Gibson Fahnestock** &lt;gibfahn@gmail.com&gt; (he/him)
* [indutny](https://github.com/indutny) -
**Fedor Indutny** &lt;fedor.indutny@gmail.com&gt;
* [isaacs](https://github.com/isaacs) -
**Isaac Z. Schlueter** &lt;i@izs.me&gt;
* [joshgav](https://github.com/joshgav) -
**Josh Gavant** &lt;josh.gavant@outlook.com&gt;
* [mscdex](https://github.com/mscdex) -
**Brian White** &lt;mscdex@mscdex.net&gt;
* [nebrius](https://github.com/nebrius) -
**Bryan Hughes** &lt;bryan@nebri.us&gt;
* [ofrobots](https://github.com/ofrobots) -
**Ali Ijaz Sheikh** &lt;ofrobots@google.com&gt; (he/him)
* [orangemocha](https://github.com/orangemocha) -
**Alexis Campailla** &lt;orangemocha@nodejs.org&gt;
* [piscisaureus](https://github.com/piscisaureus) -
**Bert Belder** &lt;bertbelder@gmail.com&gt;
* [rvagg](https://github.com/rvagg) -
**Rod Vagg** &lt;r@va.gg&gt;
* [sam-github](https://github.com/sam-github) -
**Sam Roberts** &lt;vieuxtech@gmail.com&gt;
* [shigeki](https://github.com/shigeki) -
**Shigeki Ohtsu** &lt;ohtsu@ohtsu.org&gt; (he/him)
* [thefourtheye](https://github.com/thefourtheye) -
**Sakthipriyan Vairamani** &lt;thechargingvolcano@gmail.com&gt; (he/him)
* [TimothyGu](https://github.com/TimothyGu) -
**Tiancheng "Timothy" Gu** &lt;timothygu99@gmail.com&gt; (he/him)
* [trevnorris](https://github.com/trevnorris) -
**Trevor Norris** &lt;trev.norris@gmail.com&gt;

### Collaborators

* [addaleax](https://github.com/addaleax) -
**Anna Henningsen** &lt;anna@addaleax.net&gt; (she/her)
* [aduh95](https://github.com/aduh95) -
**Antoine du Hamel** &lt;duhamelantoine1995@gmail.com&gt; (he/him)
* [ak239](https://github.com/ak239) -
**Aleksei Koziatinskii** &lt;ak239spb@gmail.com&gt;
* [AndreasMadsen](https://github.com/AndreasMadsen) -
**Andreas Madsen** &lt;amwebdk@gmail.com&gt; (he/him)
* [antsmartian](https://github.com/antsmartian) -
**Anto Aravinth** &lt;anto.aravinth.cse@gmail.com&gt; (he/him)
* [apapirovski](https://github.com/apapirovski) -
**Anatoli Papirovski** &lt;apapirovski@mac.com&gt; (he/him)
* [AshCripps](https://github.com/AshCripps) -
**Ash Cripps** &lt;acripps@redhat.com&gt;
* [bcoe](https://github.com/bcoe) -
**Ben Coe** &lt;bencoe@gmail.com&gt; (he/him)
* [bengl](https://github.com/bengl) -
**Bryan English** &lt;bryan@bryanenglish.com&gt; (he/him)
* [benjamingr](https://github.com/benjamingr) -
**Benjamin Gruenbaum** &lt;benjamingr@gmail.com&gt;
* [BethGriggs](https://github.com/BethGriggs) -
**Beth Griggs** &lt;bgriggs@redhat.com&gt; (she/her)
* [bmeck](https://github.com/bmeck) -
**Bradley Farias** &lt;bradley.meck@gmail.com&gt;
* [bmeurer](https://github.com/bmeurer) -
**Benedikt Meurer** &lt;benedikt.meurer@gmail.com&gt;
* [bnoordhuis](https://github.com/bnoordhuis) -
**Ben Noordhuis** &lt;info@bnoordhuis.nl&gt;
* [boneskull](https://github.com/boneskull) -
**Christopher Hiller** &lt;boneskull@boneskull.com&gt; (he/him)
* [BridgeAR](https://github.com/BridgeAR) -
**Ruben Bridgewater** &lt;ruben@bridgewater.de&gt; (he/him)
* [bzoz](https://github.com/bzoz) -
**Bartosz Sosnowski** &lt;bartosz@janeasystems.com&gt;
* [cclauss](https://github.com/cclauss) -
**Christian Clauss** &lt;cclauss@me.com&gt; (he/him)
* [ChALkeR](https://github.com/ChALkeR) -
**Сковорода Никита Андреевич** &lt;chalkerx@gmail.com&gt; (he/him)
* [cjihrig](https://github.com/cjihrig) -
**Colin Ihrig** &lt;cjihrig@gmail.com&gt; (he/him)
* [codebytere](https://github.com/codebytere) -
**Shelley Vohr** &lt;codebytere@gmail.com&gt; (she/her)
* [danbev](https://github.com/danbev) -
**Daniel Bevenius** &lt;daniel.bevenius@gmail.com&gt; (he/him)
* [danielleadams](https://github.com/danielleadams) -
**Danielle Adams** &lt;adamzdanielle@gmail.com&gt; (she/her)
* [davisjam](https://github.com/davisjam) -
**Jamie Davis** &lt;davisjam@vt.edu&gt; (he/him)
* [DerekNonGeneric](https://github.com/DerekNonGeneric) -
**Derek Lewis** &lt;DerekNonGeneric@inf.is&gt; (he/him)
* [devnexen](https://github.com/devnexen) -
**David Carlier** &lt;devnexen@gmail.com&gt;
* [devsnek](https://github.com/devsnek) -
**Gus Caplan** &lt;me@gus.host&gt; (they/them)
* [edsadr](https://github.com/edsadr) -
**Adrian Estrada** &lt;edsadr@gmail.com&gt; (he/him)
* [eugeneo](https://github.com/eugeneo) -
**Eugene Ostroukhov** &lt;eostroukhov@google.com&gt;
* [evanlucas](https://github.com/evanlucas) -
**Evan Lucas** &lt;evanlucas@me.com&gt; (he/him)
* [fhinkel](https://github.com/fhinkel) -
**Franziska Hinkelmann** &lt;franziska.hinkelmann@gmail.com&gt; (she/her)
* [Fishrock123](https://github.com/Fishrock123) -
**Jeremiah Senkpiel** &lt;fishrock123@rocketmail.com&gt;  (he/they)
* [Flarna](https://github.com/Flarna) -
**Gerhard Stöbich** &lt;deb2001-github@yahoo.de&gt;  (he/they)
* [gabrielschulhof](https://github.com/gabrielschulhof) -
**Gabriel Schulhof** &lt;gabriel.schulhof@intel.com&gt;
* [gdams](https://github.com/gdams) -
**George Adams** &lt;george.adams@uk.ibm.com&gt; (he/him)
* [geek](https://github.com/geek) -
**Wyatt Preul** &lt;wpreul@gmail.com&gt;
* [gengjiawen](https://github.com/gengjiawen) -
**Jiawen Geng** &lt;technicalcute@gmail.com&gt;
* [GeoffreyBooth](https://github.com/geoffreybooth) -
**Geoffrey Booth** &lt;webmaster@geoffreybooth.com&gt; (he/him)
* [gireeshpunathil](https://github.com/gireeshpunathil) -
**Gireesh Punathil** &lt;gpunathi@in.ibm.com&gt; (he/him)
* [guybedford](https://github.com/guybedford) -
**Guy Bedford** &lt;guybedford@gmail.com&gt; (he/him)
* [HarshithaKP](https://github.com/HarshithaKP) -
**Harshitha K P** &lt;harshitha014@gmail.com&gt; (she/her)
* [hashseed](https://github.com/hashseed) -
**Yang Guo** &lt;yangguo@chromium.org&gt; (he/him)
* [himself65](https://github.com/himself65) -
**Zeyu Yang** &lt;himself65@outlook.com&gt; (he/him)
* [hiroppy](https://github.com/hiroppy) -
**Yuta Hiroto** &lt;hello@hiroppy.me&gt; (he/him)
* [indutny](https://github.com/indutny) -
**Fedor Indutny** &lt;fedor.indutny@gmail.com&gt;
* [JacksonTian](https://github.com/JacksonTian) -
**Jackson Tian** &lt;shyvo1987@gmail.com&gt;
* [jasnell](https://github.com/jasnell) -
**James M Snell** &lt;jasnell@gmail.com&gt; (he/him)
* [jdalton](https://github.com/jdalton) -
**John-David Dalton** &lt;john.david.dalton@gmail.com&gt;
* [jkrems](https://github.com/jkrems) -
**Jan Krems** &lt;jan.krems@gmail.com&gt; (he/him)
* [joaocgreis](https://github.com/joaocgreis) -
**João Reis** &lt;reis@janeasystems.com&gt;
* [joyeecheung](https://github.com/joyeecheung) -
**Joyee Cheung** &lt;joyeec9h3@gmail.com&gt; (she/her)
* [juanarbol](https://github.com/juanarbol) -
**Juan José Arboleda** &lt;soyjuanarbol@gmail.com&gt; (he/him)
* [JungMinu](https://github.com/JungMinu) -
**Minwoo Jung** &lt;nodecorelab@gmail.com&gt; (he/him)
* [lance](https://github.com/lance) -
**Lance Ball** &lt;lball@redhat.com&gt; (he/him)
* [legendecas](https://github.com/legendecas) -
**Chengzhong Wu** &lt;legendecas@gmail.com&gt; (he/him)
* [Leko](https://github.com/Leko) -
**Shingo Inoue** &lt;leko.noor@gmail.com&gt; (he/him)
* [lpinca](https://github.com/lpinca) -
**Luigi Pinca** &lt;luigipinca@gmail.com&gt; (he/him)
* [lundibundi](https://github.com/lundibundi) -
**Denys Otrishko** &lt;shishugi@gmail.com&gt; (he/him)
* [mafintosh](https://github.com/mafintosh) -
**Mathias Buus** &lt;mathiasbuus@gmail.com&gt; (he/him)
* [mcollina](https://github.com/mcollina) -
**Matteo Collina** &lt;matteo.collina@gmail.com&gt; (he/him)
* [mhdawson](https://github.com/mhdawson) -
**Michael Dawson** &lt;midawson@redhat.com&gt; (he/him)
* [mildsunrise](https://github.com/mildsunrise) -
**Alba Mendez** &lt;me@alba.sh&gt; (she/her)
* [misterdjules](https://github.com/misterdjules) -
**Julien Gilli** &lt;jgilli@nodejs.org&gt;
* [mmarchini](https://github.com/mmarchini) -
**Mary Marchini** &lt;oss@mmarchini.me&gt; (she/her)
* [mscdex](https://github.com/mscdex) -
**Brian White** &lt;mscdex@mscdex.net&gt;
* [MylesBorins](https://github.com/MylesBorins) -
**Myles Borins** &lt;myles.borins@gmail.com&gt; (he/him)
* [ofrobots](https://github.com/ofrobots) -
**Ali Ijaz Sheikh** &lt;ofrobots@google.com&gt; (he/him)
* [oyyd](https://github.com/oyyd) -
**Ouyang Yadong** &lt;oyydoibh@gmail.com&gt; (he/him)
* [psmarshall](https://github.com/psmarshall) -
**Peter Marshall** &lt;petermarshall@chromium.org&gt; (he/him)
* [puzpuzpuz](https://github.com/puzpuzpuz) -
**Andrey Pechkurov** &lt;apechkurov@gmail.com&gt; (he/him)
* [Qard](https://github.com/Qard) -
**Stephen Belanger** &lt;admin@stephenbelanger.com&gt; (he/him)
* [refack](https://github.com/refack) -
**Refael Ackermann (רפאל פלחי)** &lt;refack@gmail.com&gt; (he/him/הוא/אתה)
* [rexagod](https://github.com/rexagod) -
**Pranshu Srivastava** &lt;rexagod@gmail.com&gt; (he/him)
* [richardlau](https://github.com/richardlau) -
**Richard Lau** &lt;rlau@redhat.com&gt;
* [rickyes](https://github.com/rickyes) -
**Ricky Zhou** &lt;0x19951125@gmail.com&gt; (he/him)
* [ronag](https://github.com/ronag) -
**Robert Nagy** &lt;ronagy@icloud.com&gt;
* [ronkorving](https://github.com/ronkorving) -
**Ron Korving** &lt;ron@ronkorving.nl&gt;
* [rubys](https://github.com/rubys) -
**Sam Ruby** &lt;rubys@intertwingly.net&gt;
* [ruyadorno](https://github.com/ruyadorno) -
**Ruy Adorno** &lt;ruyadorno@github.com&gt; (he/him)
* [rvagg](https://github.com/rvagg) -
**Rod Vagg** &lt;rod@vagg.org&gt;
* [ryzokuken](https://github.com/ryzokuken) -
**Ujjwal Sharma** &lt;ryzokuken@disroot.org&gt; (he/him)
* [saghul](https://github.com/saghul) -
**Saúl Ibarra Corretgé** &lt;saghul@gmail.com&gt;
* [santigimeno](https://github.com/santigimeno) -
**Santiago Gimeno** &lt;santiago.gimeno@gmail.com&gt;
* [seishun](https://github.com/seishun) -
**Nikolai Vavilov** &lt;vvnicholas@gmail.com&gt;
* [shigeki](https://github.com/shigeki) -
**Shigeki Ohtsu** &lt;ohtsu@ohtsu.org&gt; (he/him)
* [shisama](https://github.com/shisama) -
**Masashi Hirano** &lt;shisama07@gmail.com&gt; (he/him)
* [silverwind](https://github.com/silverwind) -
**Roman Reiss** &lt;me@silverwind.io&gt;
* [srl295](https://github.com/srl295) -
**Steven R Loomis** &lt;srloomis@us.ibm.com&gt;
* [starkwang](https://github.com/starkwang) -
**Weijia Wang** &lt;starkwang@126.com&gt;
* [sxa](https://github.com/sxa) -
**Stewart X Addison** &lt;sxa@redhat.com&gt; (he/him)
* [targos](https://github.com/targos) -
**Michaël Zasso** &lt;targos@protonmail.com&gt; (he/him)
* [TimothyGu](https://github.com/TimothyGu) -
**Tiancheng "Timothy" Gu** &lt;timothygu99@gmail.com&gt; (he/him)
* [tniessen](https://github.com/tniessen) -
**Tobias Nießen** &lt;tniessen@tnie.de&gt;
* [trivikr](https://github.com/trivikr) -
**Trivikram Kamat** &lt;trivikr.dev@gmail.com&gt;
* [Trott](https://github.com/Trott) -
**Rich Trott** &lt;rtrott@gmail.com&gt; (he/him)
* [vdeturckheim](https://github.com/vdeturckheim) -
**Vladimir de Turckheim** &lt;vlad2t@hotmail.com&gt; (he/him)
* [watilde](https://github.com/watilde) -
**Daijiro Wachi** &lt;daijiro.wachi@gmail.com&gt; (he/him)
* [watson](https://github.com/watson) -
**Thomas Watson** &lt;w@tson.dk&gt;
* [XadillaX](https://github.com/XadillaX) -
**Khaidi Chu** &lt;i@2333.moe&gt; (he/him)
* [yhwang](https://github.com/yhwang) -
**Yihong Wang** &lt;yh.wang@ibm.com&gt;
* [yorkie](https://github.com/yorkie) -
**Yorkie Liu** &lt;yorkiefixer@gmail.com&gt;
* [yosuke-furukawa](https://github.com/yosuke-furukawa) -
**Yosuke Furukawa** &lt;yosuke.furukawa@gmail.com&gt;
* [ZYSzys](https://github.com/ZYSzys) -
**Yongsheng Zhang** &lt;zyszys98@gmail.com&gt; (he/him)

### Collaborator Emeriti

* [andrasq](https://github.com/andrasq) -
**Andras** &lt;andras@kinvey.com&gt;
* [AnnaMag](https://github.com/AnnaMag) -
**Anna M. Kedzierska** &lt;anna.m.kedzierska@gmail.com&gt;
* [aqrln](https://github.com/aqrln) -
**Alexey Orlenko** &lt;eaglexrlnk@gmail.com&gt; (he/him)
* [brendanashworth](https://github.com/brendanashworth) -
**Brendan Ashworth** &lt;brendan.ashworth@me.com&gt;
* [calvinmetcalf](https://github.com/calvinmetcalf) -
**Calvin Metcalf** &lt;calvin.metcalf@gmail.com&gt;
* [chrisdickinson](https://github.com/chrisdickinson) -
**Chris Dickinson** &lt;christopher.s.dickinson@gmail.com&gt;
* [claudiorodriguez](https://github.com/claudiorodriguez) -
**Claudio Rodriguez** &lt;cjrodr@yahoo.com&gt;
* [DavidCai1993](https://github.com/DavidCai1993) -
**David Cai** &lt;davidcai1993@yahoo.com&gt; (he/him)
* [digitalinfinity](https://github.com/digitalinfinity) -
**Hitesh Kanwathirtha** &lt;digitalinfinity@gmail.com&gt; (he/him)
* [eljefedelrodeodeljefe](https://github.com/eljefedelrodeodeljefe) -
**Robert Jefe Lindstaedt** &lt;robert.lindstaedt@gmail.com&gt;
* [estliberitas](https://github.com/estliberitas) -
**Alexander Makarenko** &lt;estliberitas@gmail.com&gt;
* [firedfox](https://github.com/firedfox) -
**Daniel Wang** &lt;wangyang0123@gmail.com&gt;
* [gibfahn](https://github.com/gibfahn) -
**Gibson Fahnestock** &lt;gibfahn@gmail.com&gt; (he/him)
* [glentiki](https://github.com/glentiki) -
**Glen Keane** &lt;glenkeane.94@gmail.com&gt; (he/him)
* [iarna](https://github.com/iarna) -
**Rebecca Turner** &lt;me@re-becca.org&gt;
* [imran-iq](https://github.com/imran-iq) -
**Imran Iqbal** &lt;imran@imraniqbal.org&gt;
* [imyller](https://github.com/imyller) -
**Ilkka Myller** &lt;ilkka.myller@nodefield.com&gt;
* [isaacs](https://github.com/isaacs) -
**Isaac Z. Schlueter** &lt;i@izs.me&gt;
* [italoacasas](https://github.com/italoacasas) -
**Italo A. Casas** &lt;me@italoacasas.com&gt; (he/him)
* [jasongin](https://github.com/jasongin) -
**Jason Ginchereau** &lt;jasongin@microsoft.com&gt;
* [jbergstroem](https://github.com/jbergstroem) -
**Johan Bergström** &lt;bugs@bergstroem.nu&gt;
* [jhamhader](https://github.com/jhamhader) -
**Yuval Brik** &lt;yuval@brik.org.il&gt;
* [joshgav](https://github.com/joshgav) -
**Josh Gavant** &lt;josh.gavant@outlook.com&gt;
* [julianduque](https://github.com/julianduque) -
**Julian Duque** &lt;julianduquej@gmail.com&gt; (he/him)
* [kfarnung](https://github.com/kfarnung) -
**Kyle Farnung** &lt;kfarnung@microsoft.com&gt; (he/him)
* [kunalspathak](https://github.com/kunalspathak) -
**Kunal Pathak** &lt;kunal.pathak@microsoft.com&gt;
* [lucamaraschi](https://github.com/lucamaraschi) -
**Luca Maraschi** &lt;luca.maraschi@gmail.com&gt; (he/him)
* [lxe](https://github.com/lxe) -
**Aleksey Smolenchuk** &lt;lxe@lxe.co&gt;
* [maclover7](https://github.com/maclover7) -
**Jon Moss** &lt;me@jonathanmoss.me&gt; (he/him)
* [matthewloring](https://github.com/matthewloring) -
**Matthew Loring** &lt;mattloring@google.com&gt;
* [micnic](https://github.com/micnic) -
**Nicu Micleușanu** &lt;micnic90@gmail.com&gt; (he/him)
* [mikeal](https://github.com/mikeal) -
**Mikeal Rogers** &lt;mikeal.rogers@gmail.com&gt;
* [monsanto](https://github.com/monsanto) -
**Christopher Monsanto** &lt;chris@monsan.to&gt;
* [MoonBall](https://github.com/MoonBall) -
**Chen Gang** &lt;gangc.cxy@foxmail.com&gt;
* [not-an-aardvark](https://github.com/not-an-aardvark) -
**Teddy Katz** &lt;teddy.katz@gmail.com&gt; (he/him)
* [Olegas](https://github.com/Olegas) -
**Oleg Elifantiev** &lt;oleg@elifantiev.ru&gt;
* [orangemocha](https://github.com/orangemocha) -
**Alexis Campailla** &lt;orangemocha@nodejs.org&gt;
* [othiym23](https://github.com/othiym23) -
**Forrest L Norvell** &lt;ogd@aoaioxxysz.net&gt; (he/him)
* [petkaantonov](https://github.com/petkaantonov) -
**Petka Antonov** &lt;petka_antonov@hotmail.com&gt;
* [phillipj](https://github.com/phillipj) -
**Phillip Johnsen** &lt;johphi@gmail.com&gt;
* [piscisaureus](https://github.com/piscisaureus) -
**Bert Belder** &lt;bertbelder@gmail.com&gt;
* [pmq20](https://github.com/pmq20) -
**Minqi Pan** &lt;pmq2001@gmail.com&gt;
* [princejwesley](https://github.com/princejwesley) -
**Prince John Wesley** &lt;princejohnwesley@gmail.com&gt;
* [rlidwka](https://github.com/rlidwka) -
**Alex Kocharin** &lt;alex@kocharin.ru&gt;
* [rmg](https://github.com/rmg) -
**Ryan Graham** &lt;r.m.graham@gmail.com&gt;
* [robertkowalski](https://github.com/robertkowalski) -
**Robert Kowalski** &lt;rok@kowalski.gd&gt;
* [romankl](https://github.com/romankl) -
**Roman Klauke** &lt;romaaan.git@gmail.com&gt;
* [RReverser](https://github.com/RReverser) -
**Ingvar Stepanyan** &lt;me@rreverser.com&gt;
* [sam-github](https://github.com/sam-github) -
**Sam Roberts** &lt;vieuxtech@gmail.com&gt;
* [sebdeckers](https://github.com/sebdeckers) -
**Sebastiaan Deckers** &lt;sebdeckers83@gmail.com&gt;
* [stefanmb](https://github.com/stefanmb) -
**Stefan Budeanu** &lt;stefan@budeanu.com&gt;
* [tellnes](https://github.com/tellnes) -
**Christian Tellnes** &lt;christian@tellnes.no&gt;
* [thefourtheye](https://github.com/thefourtheye) -
**Sakthipriyan Vairamani** &lt;thechargingvolcano@gmail.com&gt; (he/him)
* [thlorenz](https://github.com/thlorenz) -
**Thorsten Lorenz** &lt;thlorenz@gmx.de&gt;
* [trevnorris](https://github.com/trevnorris) -
**Trevor Norris** &lt;trev.norris@gmail.com&gt;
* [tunniclm](https://github.com/tunniclm) -
**Mike Tunnicliffe** &lt;m.j.tunnicliffe@gmail.com&gt;
* [vkurchatkin](https://github.com/vkurchatkin) -
**Vladimir Kurchatkin** &lt;vladimir.kurchatkin@gmail.com&gt;
* [vsemozhetbyt](https://github.com/vsemozhetbyt) -
**Vse Mozhet Byt** &lt;vsemozhetbyt@gmail.com&gt; (he/him)
* [whitlockjc](https://github.com/whitlockjc) -
**Jeremy Whitlock** &lt;jwhitlock@apache.org&gt;
<!--lint enable prohibited-strings-->

Collaborators follow the [Collaborator Guide](./doc/guides/collaborator-guide.md) in
maintaining the Node.js project.

### Triagers

* [PoojaDurgad](https://github.com/PoojaDurgad) -
**Pooja Durgad** &lt;Pooja.D.P@ibm.com&gt;

### Release Keys

Primary GPG keys for Node.js Releasers (some Releasers sign with subkeys):

* **Beth Griggs** &lt;bgriggs@redhat.com&gt;
`4ED778F539E3634C779C87C6D7062848A1AB005C`
* **Colin Ihrig** &lt;cjihrig@gmail.com&gt;
`94AE36675C464D64BAFA68DD7434390BDBE9B9C5`
* **James M Snell** &lt;jasnell@keybase.io&gt;
`71DCFD284A79C3B38668286BC97EC7A07EDE3FC1`
* **Michaël Zasso** &lt;targos@protonmail.com&gt;
`8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600`
* **Myles Borins** &lt;myles.borins@gmail.com&gt;
`C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8`
* **Richard Lau** &lt;rlau@redhat.com&gt;
`C82FA3AE1CBEDC6BE46B9360C43CEC45C17AB93C`
* **Rod Vagg** &lt;rod@vagg.org&gt;
`DD8F2338BAE7501E3DD5AC78C273792F7D83545D`
* **Ruben Bridgewater** &lt;ruben@bridgewater.de&gt;
`A48C2BEE680E841632CD4E44F07496B3EB3C1762`
* **Ruy Adorno** &lt;ruyadorno@hotmail.com&gt;
`108F52B48DB57BB0CC439B2997B01419BD92F80A`
* **Shelley Vohr** &lt;shelley.vohr@gmail.com&gt;
`B9E2F5981AA6E0CD28160D9FF13993A75599653C`

To import the full set of trusted release keys:

```bash
gpg --keyserver pool.sks-keyservers.net --recv-keys 4ED778F539E3634C779C87C6D7062848A1AB005C
gpg --keyserver pool.sks-keyservers.net --recv-keys 94AE36675C464D64BAFA68DD7434390BDBE9B9C5
gpg --keyserver pool.sks-keyservers.net --recv-keys 71DCFD284A79C3B38668286BC97EC7A07EDE3FC1
gpg --keyserver pool.sks-keyservers.net --recv-keys 8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600
gpg --keyserver pool.sks-keyservers.net --recv-keys C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8
gpg --keyserver pool.sks-keyservers.net --recv-keys C82FA3AE1CBEDC6BE46B9360C43CEC45C17AB93C
gpg --keyserver pool.sks-keyservers.net --recv-keys DD8F2338BAE7501E3DD5AC78C273792F7D83545D
gpg --keyserver pool.sks-keyservers.net --recv-keys A48C2BEE680E841632CD4E44F07496B3EB3C1762
gpg --keyserver pool.sks-keyservers.net --recv-keys 108F52B48DB57BB0CC439B2997B01419BD92F80A
gpg --keyserver pool.sks-keyservers.net --recv-keys B9E2F5981AA6E0CD28160D9FF13993A75599653C
```

See the section above on [Verifying Binaries](#verifying-binaries) for how to
use these keys to verify a downloaded file.

Other keys used to sign some previous releases:

* **Chris Dickinson** &lt;christopher.s.dickinson@gmail.com&gt;
`9554F04D7259F04124DE6B476D5A82AC7E37093B`
* **Evan Lucas** &lt;evanlucas@me.com&gt;
`B9AE9905FFD7803F25714661B63B535A4C206CA9`
* **Gibson Fahnestock** &lt;gibfahn@gmail.com&gt;
`77984A986EBC2AA786BC0F66B01FBB92821C587A`
* **Isaac Z. Schlueter** &lt;i@izs.me&gt;
`93C7E9E91B49E432C2F75674B0A78B0A6C481CF6`
* **Italo A. Casas** &lt;me@italoacasas.com&gt;
`56730D5401028683275BD23C23EFEFE93C4CFFFE`
* **Jeremiah Senkpiel** &lt;fishrock@keybase.io&gt;
`FD3A5288F042B6850C66B31F09FE44734EB7990E`
* **Julien Gilli** &lt;jgilli@fastmail.fm&gt;
`114F43EE0176B71C7BC219DD50A3051F888C628D`
* **Timothy J Fontaine** &lt;tjfontaine@gmail.com&gt;
`7937DFD2AB06298B2293C3187D33FF9D0246406D`

[Code of Conduct]: https://github.com/nodejs/admin/blob/master/CODE_OF_CONDUCT.md
[Contributing to the project]: CONTRIBUTING.md
[Node.js Website]: https://nodejs.org/
[OpenJS Foundation]: https://openjsf.org/
[Strategic Initiatives]: https://github.com/nodejs/TSC/blob/master/Strategic-Initiatives.md
[Technical values and prioritization]: doc/guides/technical-values.md
[Working Groups]: https://github.com/nodejs/TSC/blob/master/WORKING_GROUPS.md
ons, I have not validated AMD GPU or Intel GPU inference in this project.
- If you require AMD/Intel production usage, you need to explore, adapt, and validate the stack on your own hardware.
