curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
. /.nvm/nvm.sh
nvm install 16
npm install yarn -g

wget https://github.com/juspay/hyperswitch-cdk/archive/refs/heads/main.zip
unzip main.zip
cd $(unzip -Z -1 main.zip| head -1)
yarn install

yarn cdk deploy --require-approval never -c test=true