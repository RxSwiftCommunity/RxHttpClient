carthage checkout
carthage build --platform iOS
mkdir -p ./Dependencies/iOS
cp -R ./Carthage/Build/iOS/*.framework ./Dependencies/iOS