###################################################
#          Configurações do display:              #
#                                                 #
# Unit Width in pixels:    8                      #
# Unit Height in pixels:   8                      #
# Display Width in pixels: 512                    #
# Unit Height in pixels:   8                      #
# Base adress for display: 0x10010000             #
#                                                 #
# Tamanho de 1 linha: 512 / 8 = 64                #
# Tamanho de 1 coluna: 256 / 8 = 32               #
###################################################

# Definição de alguns macros para simplificar o código.
# Códigos para cores
.eqv VERDE    0X007fd500                # COR DO BACKGROUND
.eqv PRETO    0X00303039                # COR DA BORDA
.eqv AZUL     0x0000bfff                # COR DA COBRA
.eqv VERMELHO 0x00d80000                # COR DA COMIDA

.data

display: .space 8192                    # 512 * 256 * 4
comida:  .word  4224                    # posição inicial da comida

.text
main:

# fundo do display                       
ori $a0, $zero, 2048                    # 64 * 32 = 2048
or  $a1, $zero, $zero                   # display inteiro; começa da pos. 0
ori $a2, $zero, 4                       #
ori $a3, $zero, VERDE                   #

jal desenhaDisplay

# borda superior ($a1 e $a2 continuam iguais)
ori $a0, $zero, 64                      # 512/8 = 64 (64 colunas)
ori $a3, $zero, PRETO                   # muda a cor para PRETO

jal desenhaDisplay

# borda inferior ($a0, $a2 e $a3 continuam iguais)
ori $a1, $zero, 7936                   # começa na última linha

jal desenhaDisplay

# borda esquerda ($a0 e $a3 continuam iguais)
ori $a0, $zero, 30                     # 256/8 - 2 = 30 (32 linhas)
ori $a1, $zero, 256                    # 64 * 4 = 256 (n_colunas * n_pos_mem)
ori $a2, $zero, 256

jal desenhaDisplay

# borda direita ($a0, $a2 e $a3 continuam iguais)
ori $a1, $zero, 508                    # penúltima coluna da segunda linha (256*2 - 4)

jal desenhaDisplay

# desenha a comida em uma posição aleatória
#jal novaPosicaoComida                  # novo endereço aleatório
#move $a0, $v0
lw $a0, comida                         # inicia com a comida no centro
jal desenhaComida                      # desenha comida

#j exit


# Subrotina para desenhar as bordas e o fundo do display
# args
#  $a0: comprimento (horizontal -> 64; vertical -> 64)
#  $a1: deslocamento (endereço inicial adicionado ao buffer)
#  $a2: incremento (horizontal -> 4; vertical -> 256)
#  $a3: cor
# valor de retorno
#  void
desenhaDisplay:
la   $t0, display                        # carrega o endereço inicial do display
move $t1, $a0                            # salva comprimento (contador)
add  $t0, $t0, $a1                       # adiciona delocamento ao endereço base
move $t2, $a3                            # carrega a cor da borda

loop:
sw   $t2, 0($t0)                         # desenha o pixel
add  $t0, $t0, $a2                       # incremeta o endereço do display
addi $t1, $t1, -1                        # decrementa o contador
bnez $t1, loop                           # continua enquanto contador > 0
jr   $ra

# Subrotina para gerar nova posição da comida
# valor de retorno
#  $v0: endereço da nova posição
novaPosicaoComida:
random:
li $v0, 42                               # chamada de sistema 42: int aleatório com limite superior
li $a1, 7936                             # limite superior: 256 * 512 / 16 - 256 = 7936 (menos última linha)
syscall

andi $t3, $a0, 3                         # converte para o múltiplo de 4 mais próximo (abaixo)
sub  $t3, $a0, $t3                       # a - (a ^ 3) (em binário)

# verifica se está em cima das bordas
ori  $t6, $zero, 256                     # valor 256
or   $t7, $zero, $t3                     # copia $t3 para $t7
addi $t7, $t7, -252                      # desconta 252  (borda direita)

div  $t3, $t6                            # $t4 = $t3 % 256
mfhi $t4

beqz $t4, random

div  $t7, $t6                            # $t4 = $t7 % 256
mfhi $t4

beqz $t4, random

slt  $t4, $t3, $t6                       # borda superior ($t4 = $t3 < 256)

bnez $t4, random

move $v0, $t3
jr   $ra

# Subrotina para desenhar a comida
# args
#  $a0: posição para desenhar a comida
# valor de retorno
#  void
desenhaComida:
la  $t0, display                          # carrega o endereço inicial do display
li  $t2, VERMELHO								          # carrega a cor da comida

add $t0, $t0, $a0                         # adiciona ao endereço base
sw  $t2, 0($t0)                           # armazena a
jr  $ra

exit:
li $v0, 10
syscall