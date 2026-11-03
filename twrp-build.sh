#!/usr/bin/env bash

tg() {
    local msg="$1"
if [[ -n ${TG_CHAT_ID} && -n ${TG_TOKEN} ]]; then
    curl -s "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
        --data-urlencode "text=$msg" \
        --data-urlencode "chat_id=${TG_CHAT_ID}"
fi
}

cd /twrp

dl_ccache() { }

sync() {
tg $(cat <<'EOF'
REPO SYNC STARTED!

MANIFEST_URL: ${MANIFEST_URL}
MANIFEST_BRANCH: ${MANIFEST_BRANCH}
EOF
)"
repo init --depth=1 -u ${MANIFEST_URL} -b ${MANIFEST_BRANCH}
repo sync  -j$(nproc --all)
}

clone_dt() {
git clone ${DEVICE_TREE_URL} -b ${DEVICE_TREE_BRANCH} ${DEVICE_PATH}
tg "$(cat <<'EOF'
CLONING DEVICE TREE
DT URL: ${DEVICE_TREE_URL}
DT BRANCH: ${DEVICE_TREE_BRANCH}
DT PATH: ${DEVICE_PATH}
EOF
)"

}

# common tree
clone_cdt() {
git clone ${OMMON_TREE_URL} -b ${COMMON_DEVICE_TREE_BRANCH} ${COMMON_PATH}
}

build() {
tg "$(cat <<'EOF'
Build Started:
MAKEFILE: ${MAKEFILE_NAME}
BUILD TARGET: ${BUILD_TARGET}
EOF
)"
source build/envsetup.sh
export ALLOW_MISSING_DEPENDENCIES=true
lunch ${MAKEFILE_NAME}-eng
make ${BUILD_TARGET}image -j$(nproc --all) &&tg "Build Completed!"
}

build_clean() {
tg "$(cat <<'EOF'
Build Started:
Build: Clean
MAKEFILE: ${MAKEFILE_NAME}
BUILD TARGET: ${BUILD_TARGET}
EOF
)"
source build/envsetup.sh
export ALLOW_MISSING_DEPENDENCIES=true
lunch ${MAKEFILE_NAME}-eng
make clean
make ${BUILD_TARGET}image -j$(nproc --all) &&tg "Build Completed!"
}

up_ccache() {
cd /tmp
com ()
{
    tar --use-compress-program="pigz -k -$2 " -cf $1.tar.gz $1
}

time com ccache 1
curl https://sendit.sh -T ccache.tar.gz >> upload.txt

tg "$(cat upload.txt)"
}

up_recovery() {
cd $OUT
curl https://sendit.sh -T boot.img >> upload.txt
tg "$(cat upload.txt)"
}

echo "$(cat <<'EOF'
BUILD FLAGS
EOF
)"

if [[ -n ${MANIFEST_URL} && -n ${MANIFEST_BRANCH} ]]; then
   sync()
fi

if [[ -n ${DEVICE_TREE_URL} && -n ${DEVICE_TREE_BRANCH} ]]; then
   clone_dt()
fi

if [[ "${1}" == "clean" ]]; then
  if [[ -n ${MAKEFILE_NAME} && -n ${BUILD_TARGET} ]]; then
     build_clean()
  fi
else
  if [[ -n ${MAKEFILE_NAME} && -n ${BUILD_TARGET} ]]; then
     build()
  fi
fi
if [[ -n ${UPLOAD_CCACHE}]]; then
   up_ccache()
fi
