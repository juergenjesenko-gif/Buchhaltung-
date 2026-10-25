#!/usr/bin/env bash
# Holt die Website-Medien aus der Marketing-Übergabe 2026-10-25 und wandelt sie
# für die Website um. Läuft im GitHub-Runner (.github/workflows/medien_holen.yml).
set -euo pipefail
B=https://d2ol7oe51mr4n9.cloudfront.net/user_3L1A1wsa9qthsCrfkFir8sGmuGl
T=$(mktemp -d)
S=docs/site
mkdir -p $S/video $S/img/social $S/img/app $S/img/features
dl(){ curl -fsSL --retry 3 -o "$T/$2" "$B/$1"; }
webp(){ ffmpeg -loglevel error -y -i "$1" -vf "scale='min($3,iw)':-2" -c:v libwebp -quality 80 "$2"; }
video(){ # Name, Datei
  dl "$2" "$1.mp4"
  ffmpeg -loglevel error -y -i "$T/$1.mp4" -vf scale=720:-2 -c:v libx264 -crf 26 -preset slow \
    -profile:v high -pix_fmt yuv420p -c:a aac -b:a 96k -movflags +faststart "$S/video/$1.mp4"
  ffmpeg -loglevel error -y -ss 1 -i "$T/$1.mp4" -frames:v 1 -vf scale=720:-2 -c:v libwebp -quality 80 "$S/video/$1.webp"
}
video reel_belege_automatisch 4a48f794-6562-4a8b-b96b-80e0c8fb7c4f.mp4
video reel_e-rechnung cb14db4d-d28a-40f9-8b3f-f4b78b45cd90.mp4
video reel_vertraege a34cb22a-fb66-44cb-96be-7e9a05d633d9.mp4
video reel_fitness 92c95c88-a8a0-497f-98a8-3a3d9fd467e6.mp4
video reel_floristin ca77bbee-d10e-4d6c-bf83-1467fc421770.mp4
video reel_elektrikerin 5c8d48d5-70a5-430c-bbf5-f4117c9bf1e5.mp4
video reel_hundetrainerin 54afb0bd-7bbd-457c-9888-281db9412b59.mp4
video reel_friseurin 10a9180e-1e26-43fe-a652-c35f6e308226.mp4
video reel_beraterin dd1adb5e-11af-4a0c-b254-5eb6faac8e18.mp4
video reel_assistentin b58eb861-1b34-439f-8891-1e6c9671b7bb.mp4
img(){ dl "$2" "$(basename "$1").png"; webp "$T/$(basename "$1").png" "$S/$1.webp" "$3"; }
img img/social/elektrikerin_1 4be1d3ac-ad4f-4fc4-a1e2-6b6427bb4880.png 720
img img/social/elektrikerin_2 7e2fb548-e1c1-49c3-8eff-e592ba909bdf.png 720
img img/social/hundetrainerin_1 62a332d7-d5fc-4fb9-9f5b-4aeec8401bc8.png 720
img img/social/hundetrainerin_2 bc13d58a-9099-40f7-92a2-18e048e516b1.png 720
img img/social/friseurin_1 427c737c-9aad-4f0a-96e1-93142506c25a.png 720
img img/social/friseurin_2 e6472536-9298-425b-ab1e-16ff774931c7.png 720
img img/social/beraterin_1 0ad9eb4b-21b9-4f3a-929a-9cb5bf0fff52.png 720
img img/social/beraterin_2 4ff721e3-9dbc-4afc-88aa-6ad7539b6572.png 720
img img/social/assistentin_1 fb563d87-0134-4b33-985c-345ab89d6ad3.png 720
img img/social/assistentin_2 cc849930-d5aa-4418-8ff1-8ae0282c2915.png 720
img img/social/post_das_ist_jeni b3de043b-2423-4ffa-8f11-cf9fde84f120.png 720
img img/social/cta 1202bf0d-dba1-4c15-8232-051fb67d918c.png 720
img img/features/web_belege 3c7adcf3-0e19-46f1-b7ac-125f7f5c5ad3.png 1600
img img/features/web_erechnung 345b8356-5a3b-4273-828a-a5f31d26e3b9.png 1600
img img/features/web_vertraege d37a9107-b8cf-4321-ac10-7e5c37a74a7b.png 1600
img img/app/7_angebot 886c860d-4674-43e1-bbac-e785d31e0f31.png 1080
img img/app/8_erechnung d2f888b5-aa1c-492d-936d-71416291a851.png 1080
img img/app/9_rechnungen f74a7bda-c5a1-4ca8-aa43-68b4722a089b.png 1080
img img/app/10_vertrag_scan 8a98bcf7-d828-4296-b382-8d58e08742a4.png 1080
img img/app/11_vertrag_kurzuebersicht 8827e4aa-9cf8-4066-bbc8-8695224c5530.png 1080
img img/app/12_vertrag_zahlung c97f707d-dcdb-4e63-8641-f89a6d63597d.png 1080
du -sh $S/video $S/img
