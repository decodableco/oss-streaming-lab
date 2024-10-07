#!/bin/bash

mkdir -p model/bert-base-multilingual-uncased-sentiment
curl -L "https://drive.usercontent.google.com/download?id=1EN2cMHShxktpQUJ9lYvdEvnsdDbDio6o&export=download&confirm=y" -o ./model/bert-base-multilingual-uncased-sentiment/model_quantized.onnx
curl -L "https://drive.usercontent.google.com/download?id=1jVvLOV-x4qP8tIsoHyG8T1QotM0Bur1Z&export=download&confirm=y" -o ./model/bert-base-multilingual-uncased-sentiment/tokenizer.json
