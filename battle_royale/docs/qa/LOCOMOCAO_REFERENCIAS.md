# Locomoção humana — resposta da passada

## Critério observado

A locomoção tem de passar por quatro estados contínuos: repouso, arranque, passada sustentada e frenagem. Em humanos, uma ordem de parar não zera imediatamente o movimento do centro de massa; a terminação acontece ao longo dos passos. Estudos de captura de movimento que incluem transições caminhada/corrida e mudanças contínuas de velocidade reforçam que a passada precisa se adaptar durante a aceleração e a desaceleração.

Referências primárias:

- [Lower-limb kinematics and kinetics during continuously varying human locomotion](https://pmc.ncbi.nlm.nih.gov/articles/PMC8553836/) — transições caminhada/corrida e aceleração/desaceleração monitoradas com captura 3D e plataforma de força.
- [The Effect of Stimulus Timing on Unplanned Gait Termination](https://pubmed.ncbi.nlm.nih.gov/27046933/) — o movimento do centro de massa pode continuar além do primeiro passo após o aviso de parada; a frenagem é distribuída no ciclo de marcha.
- [Changes in acceleration and deceleration factors associated with active gait speed adjustment](https://pmc.ncbi.nlm.nih.gov/articles/PMC11060761/) — ajuste ativo da marcha ao mudar velocidade.

## Implementação e medida

`game/core/body_model.gd` separa a velocidade de pose da velocidade física. O vetor visual acelera a 13 m/s² e freia a 9,5 m/s², em espaço local; curvas e inversões de direção também passam por essa resposta. O parâmetro de velocidade do ciclo usa a mesma passada e desce continuamente até quase zero, para os pés não continuarem girando em velocidade mínima enquanto o corpo já parece parado.

O teste isolado `game/tests/locomotion_smoke.tscn` evita montar a ilha inteira e mede a mesma pose usada pelos personagens:

| Instante | Velocidade visual medida |
|---|---:|
| 0,10 s após iniciar movimento | 1,22 m/s |
| passada já sustentada | 5,50 m/s |
| 0,08 s após soltar o controle | 5,06 m/s |
| 0,92 s após soltar | 0,00 m/s |

As três afirmações passam por `assert`: arrancada abaixo da velocidade de corrida, passada persistente e decrescente após soltar, repouso completo no final. A cena também foi executada em janela usando Compatibility na GT 730 e salvou a sequência `raw/locomotion_visual/locomocao_{arranque,corrida,freio,repouso}.png`; a pose de freio mostra a perna ainda completando a passada, enquanto a captura final já está em repouso.

## Avaliação do Mixamo e limite atual

No Mixamo foram inspecionados/baixados sem skin, 30 fps: `Rifle Run`, `Rifle Start Run`, `Rifle Walk To Stop`, `Walk Forward` (rifle) e `Rifle Aiming Idle`. As cópias-fonte estão em `game/assets/animations/mixamo_source/`. O pacote do jogo usa 44 ossos; o FBX Mixamo traz 65. Há 41 nomes de ossos correspondentes, mas a escala, os eixos de repouso e os rolls de ombro, pé e mão diferem bastante. Por isso não é seguro apontar o FBX diretamente para o rig de jogo: causaria rotações e pegadas erradas.

`tools/compare_mixamo_rig.py` registra a diferença. `tools/retarget_mixamo.py` e `raw/terrorist_mixamo_test.glb` são um protótipo de transferência de rotação da cadeia inferior; a exportação atual ainda deixa ações auxiliares Mixamo sem alvo e não é usada pelo jogo. Não trocar os clipes de produção por esse protótipo antes de validar a captura em ciclo, o contato dos pés, a transição, a hitbox e a pose de arma em primeira e terceira pessoa.

## Próximo portão de qualidade

Antes de promover qualquer clip Mixamo: retargetar uma cadeia de perna por vez mantendo a proporção do personagem, importar como AnimationLibrary sem duplicar malha, comparar lado a lado walk/run/arranque/freio em piso plano e inclinado, medir deslize do pé em apoio e testar rifle/pistola/faca. Uma animação que melhora a passada mas entorta mãos, cabeça ou arma não passa.
