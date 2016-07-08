carthage update --no-build
carthage build --platform iOS
mkdir -p ./Dependencies/iOS
./Scripts/CopyFrameworks.sh
#cp -R ./Carthage/Build/iOS/*.framework ./Dependencies/iOS