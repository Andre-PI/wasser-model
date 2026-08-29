# Fine-tune para gado em vista aerea

## Por que isto existe

Os pesos genericos (COCO) **nao funcionam** neste caso de uso. Medido no
video de teste do projeto (`videos/`, drone, 720x720), com `yolo26x.pt`:

| imgsz | conf | deteccoes |
| --- | --- | --- |
| 640 (padrao do projeto) | 0.25 | **0** |
| 640 | 0.10 | 1, rotulada `bird` |
| 1280 | 0.25 | **37, todas rotuladas `bird`** |

As caixas caem em cima do gado, mas o modelo o classifica como **passaro**:
de cima, um boi nao se parece com as fotos de nivel do chao do COCO. Como o
pipeline filtra `classes=[19]` ("cow"), o contador fica em zero para sempre.

Somam-se dois problemas: em `imgsz=640` quase nada e detectado (o animal e
pequeno demais), e o que e detectado sai com o rotulo errado.

Fine-tune com dados aereos rotulados resolve os dois de uma vez.

## Fluxo

```bash
# 1. Extrai frames dos videos (1 a cada 10)
uv run python training/extract_frames.py --step 10

# 2. Gera rotulos-rascunho reaproveitando as caixas do modelo generico
uv run python training/pre_annotate.py --imgsz 1280 --conf 0.25

# 3. >>> REVISE OS ROTULOS A MAO <<<  (ver secao abaixo)

# 4. Divide em train/val
uv run python training/split_dataset.py --val-ratio 0.2

# 5. Treina
uv run python training/train.py --epochs 100 --imgsz 1280 --device 0
```

## O passo 3 nao e opcional

O `pre_annotate.py` ignora o rotulo do modelo e fica so com as caixas,
marcando tudo como classe 0 (`cattle`). Isso adianta a maior parte do
trabalho, mas o rascunho **tem erro**: falsos positivos (sombras, pedras,
aves de verdade) e animais perdidos, principalmente os sobrepostos.

Treinar em cima do rascunho sem revisar so ensina o modelo a repetir os
erros do modelo generico. Abra `training/dataset/` em uma ferramenta de
rotulagem (Label Studio, CVAT, Roboflow) e corrija.

## Sobre o tamanho do dataset

O repositorio tem **um** video. Extraindo 1 a cada 10 frames saem ~109
imagens, todas da mesma cena, mesmo rebanho, mesma altitude e mesma luz.
Frames vizinhos sao quase identicos.

Isso da para validar o fluxo, **nao** para treinar um modelo que generalize.
Para producao, junte filmagens de varios dias, altitudes, horarios e pastos.
O `split_dataset.py` corta em bloco (nao embaralha) justamente para os
frames vizinhos nao vazarem do treino para a validacao e inflarem a metrica.

## Depois de treinar

Os pesos saem em `runs/<name>/weights/best.pt`. Para usar:

1. Aponte `DEFAULT_MODEL_PATH` em `processor.py` para esse arquivo.
2. Passe `class_ids=[CATTLE_CLASS_ID]` em `process_video()` — o modelo
   fine-tunado tem uma classe so, indice 0, nao a 19 do COCO.
3. Considere `imgsz=1280`; o padrao 640 perde animal pequeno.

O ReID do tracker (`model:` em `wasser_tracker.yaml`) continua usando os
pesos genericos de classificacao — e independente do detector.
