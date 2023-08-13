# pyrfc-in-docker
## How to build the docker image?

docker build . --build-arg NWRFC_ZIP=`[NWRFC zip file]` --build-arg SAPCAR_EXE=`[SAPCAR executable]` --build-arg CRYPTOLIB_SAR=`[cryptolib archive]` --secret id=key,src=`[p12 file with private key]` --secret id=pass,src=`[path to file containing passphrase for p12 file]` -t pyrfc:0.1