#!/bin/bash
cd "$(dirname "$0")/.."


echo "---------------------------------------"
echo "Building Upsilon API..."
echo "---------------------------------------"
cd upsilonapi || exit
go build -o bin/upsilonapi .
cd ..

echo "---------------------------------------"
echo "Building Upsilon CLI..."
echo "---------------------------------------"
cd upsiloncli || exit
go build -o bin/upsiloncli ./cmd/upsiloncli
cd ..

echo "---------------------------------------"
echo "Building Upsilon Hub..."
echo "---------------------------------------"
cd upsilonhub || exit
go build -o bin/upsilonhub ./cmd/upsilonhub
cd ..

echo "---------------------------------------"
echo "Building Upsilon Economy..."
echo "---------------------------------------"
cd upsiloneconomy || exit
go build -o bin/upsiloneconomy ./cmd/upsiloneconomy
cd ..

echo "---------------------------------------"
echo "Building SPA (upsilonbattleui)..."
echo "---------------------------------------"
cd upsilonbattleui || exit
npm run build
cd ..