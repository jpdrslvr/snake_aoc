###################################################################
#          Configurações do display:                              #
#                                                                 #
# Unit Width in pixels:   16                                      #
# Unit Height in pixels:  16                                      #
# Display Width in pixels: 512                                    #
# Unit Height in pixels:   512                                    #
# Base adress for display: 0x10010000                             #
#                                                                 #
# Tamanho de 1 linha: 512 / 16 = 32                               #
# Tamanho de 1 coluna: 512 / 16 = 32                              #
#                                                                 #
#-----------------------------------------------------------------#
#                                                                 #
#          Instruções para jogar                                  #
#                                                                 #
# Tools -> Bitmap Display -> Connect to MIPS                      #
# Tools -> Keyboard and Display MMIO Simulator -> Connect to MIPS #
#                                                                 #
###################################################################

# Algumas fontes que foram usadas como inspiração
# https://github.com/shahmaty/assemblySnake/blob/main/snake.s
# https://github.com/BuildSucceeded/Snake
# https://www.programminghomeworkhelp.com/bitmap-display-mips-assembly/
# https://www.youtube.com/watch?v=XEeZujXWpZg&t=308s
# https://www.reddit.com/r/learnprogramming/comments/4fxr73/mips_understanding_memory_mapped_io_and_polling/
# https://stackoverflow.com/questions/40051870/polling-i-o-mips
# https://courses.missouristate.edu/KenVollmar/mars/Help/MacrosHelp.html
# https://courses.missouristate.edu/kenvollmar/mars/help/syscallhelp.html

# CORES
.eqv COR_BORDA  0X00303039                   # Cinza escuro
.eqv COR_FUNDO  0X007fd500                   # Verde
.eqv COR_COMIDA 0x00d80000                   # Vermelho
.eqv COR_SNAKE  0X00303039                   # Cinza escuro

# CORES COM DIREÇÃO
.eqv COR_SNAKE_UP $s3                        # ↑ para cima
.eqv COR_SNAKE_RGHT $s4                      # → para direita
.eqv COR_SNAKE_DWN $s5                       # ↓ para baixo
.eqv COR_SNAKE_LFT $s6                       # ↓ para esquerda

# CONSTANTES
.eqv RECEIVER_CTRL 	   0xffff0000            # Endereço de controle do simulador de teclado
.eqv RECEIVER_DATA     0xffff0004            # Endereço de dados do simulador de teclado
.eqv TRANSMITTER_CTRL  0xffff0008            # Endereço de controle do display de texto
.eqv TRANSMITTER_DATA  0xffff000c            # Endereço de dados do display de texto
.eqv SCORE             $t9                   # Pontuação

.data
# Aloca memória para o desenhar no display
display:      .space 4096                    # 16 * 16 * 4; Começa no início da seção .data

# Posição (x, y) inicial da cabeça
headX:        .byte  10
headY:        .byte  10

# Posição (x, y) inicial da cabeça
tailX:        .byte  6
tailY:        .byte  10

# Direção inicial (x, y):
# (0, -1)  ↑ para cima
# (1,  0)  → para direita
# (0,  1)  ↓ para baixo
# (-1, 0)  ← para esquerda
dirX:         .byte  1                       # direção x
dirY:         .byte  0                       # direção y

# Strings
gameOverStr1: .asciiz "Game over.\nScore: "
gameOverStr2: .asciiz "\n-------------"

.text
main:
# Salva nos registradores $s3 - $s6 as cores correspondentes às direções
# Cinza escuro (último byte é a direção da tail)
# útil para saber a próxima posição da tail
ori $t0, $zero, 0x01000000
move $t1, $t0
ori $t2, $zero, COR_SNAKE                    

add $s3, $t1, $t2                        # ↑ para cima

add $t1, $t1, $t0
add $s4, $t1, $t2                        # → para direita

add $t1, $t1, $t0
add $s5, $t1, $t2                        # ↓ para baixo

add $t1, $t1, $t0
add $s6, $t1, $t2                        # ↓ para esquerda

# Desenha o fundo do display e as bordas
# Fundo                       
ori $a0, $zero, 1024                         # 16 * 16 * 4 = 1024
or  $a1, $zero, $zero                        # display inteiro; começa da pos. 0
ori $a2, $zero, 4
ori $a3, $zero, COR_FUNDO
jal desenhaDisplay

# Bordas superior e inferior ($a1 e $a2 continuam iguais) 
ori $a0, $zero, 32                           # 32 colunas
ori $a3, $zero, COR_BORDA                    # muda a cor para a cor da borda
jal desenhaDisplay

ori $a1, $zero, 3968                         # Muda para última linha do display
jal desenhaDisplay

# Bordas laterais ($a0 e $a3 continuam iguais)
ori $a0, $zero, 30                           # 32 linhas
ori $a1, $zero, 128                          # 32 * 4 = 256 (n_colunas * n_pos_mem)
ori $a2, $zero, 128
jal desenhaDisplay

ori $a1, $zero, 252                          # penúltima coluna da segunda linha (256 - 4)
jal desenhaDisplay

# Desenha a snake
lb $a0, headX
lb $a1, headY
jal converteXY

ori  $a0, $zero, 5
move $a1, $v0
ori  $a2, $zero, -4                        
or  $a3, $zero, COR_SNAKE_RGHT
jal desenhaDisplay

# gera posição inicial da comida e desenha na tela
jal novaPosicaoComida
move $a0, $v0
jal desenhaComida

# Incicializa o score como 0
move SCORE, $zero

espera:
# Enquanto nenhuma tecla é pressionada, nada acontece
jal sleep

lw   $t0, RECEIVER_CTRL                      # Quando uma tecla for pressionada, essa flag vai ser 1
beqz $t0, espera

################################################################
# ------------------------ LOOP DO JOGO ------------------------
loopJogo:
beq $s7, 1, geraNovaComida                   # if ($s7 == 1) goto geraNovaComida
j naoGeraComida                              # else naoGeraComida

geraNovaComida:
jal novaPosicaoComida                        # nova posição aleatória
move $a0, $v0
jal desenhaComida                            # desenha a comida
move $s7, $zero                              # zera flag $s7
addi SCORE, SCORE, 1                         # Incrementa o score

naoGeraComida:
jal move_                                    # move para a próxima posição
jal sleep                                    # sleep por 60 ms
jal poll                                     # input do teclado (próxima direção)


j loopJogo
# ------------------------ LOOP DO JOGO ------------------------
################################################################

pause:
jal sleep
# Enquanto nenhuma tecla é pressionada, nada acontece
jal sleep

lw   $t0, RECEIVER_CTRL                      # Quando uma tecla for pressionada, essa flag vai ser 1
beqz $t0, espera
j loopJogo

gameOver:
jal sleep
# Reseta na memória as variáveis de controle do jogo

ori $t0, $zero, 10
sb  $t0, headX
sb  $t0, headY
sb  $t0, tailY

ori $t0, $zero, 6
sb  $t0, tailX

ori $t0, $zero, 1
sb  $t0, dirX
sb  $zero, dirY

jal printScore

j main

# Sai do loop principal e termina o programa
exit:
li $v0, 10
syscall


# ------------------------ SUBROTINAS ------------------------
# Subrotina para desenhar no display
# args
#  $a0: comprimento (horizontal -> 64; vertical -> 64)
#  $a1: deslocamento (endereço inicial adicionado ao buffer)
#  $a2: incremento
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
addi $sp, $sp, -4                         # aloca memória no stack
sw   $ra, 0($sp)                          # salva o return address
random:
# gera coord Y aleatória
li $v0, 42                               # chamada de sistema 42: int aleatório com limite superior
li $a1, 31                               # limite superior: 31
syscall 
move $s1, $a0                            # guarda Y

# gera coord X aleatória
li $v0, 42                               # chamada de sistema 42: int aleatório com limite superior
li $a1, 31                               # limite superior: 31
syscall

move $a1, $a0
move $a0, $s1
jal converteXY                           # converte de (x, y) para endereço

la  $t7, display
add $t7, $t7, $v0
lw  $t8, 0($t7)                          # lê o pixel da nova posição
bne $t8, COR_FUNDO, random               # se for diferente do fundo, gera outra coordenada

move $v0, $t7                            # move o endereço para $v0

lw $ra, 0($sp)                            # carrega o $ra
addiu $sp, $sp, 4                         # libera o stack

jr   $ra

# Subrotina para desenhar a comida
# args
#  $a0: posição para desenhar a comida
desenhaComida:
li  $t2, COR_COMIDA			       	          # carrega a cor da comida

sw  $t2, 0($a0)                           # armazena a
jr  $ra


# Subrotina sleep por n milissegundos
sleep:
li $v0, 32                               # chamada de sistema 32: sleep
li $a0, 100                              # tempo em milissegundos
syscall
jr $ra

# Subrotina para converter coord (x, y) para endereço
# args
#  $a0; x
#  $a1: y
# valor de retorno
#  $v0: endereço
converteXY:
# move argumentos para registradores temporários
move $t2, $a0
move $t1, $a1
                                         # (x + (32y)) * 4
sll $t1, $t1, 5                          # multiplica y por 32 usando shift
add $t1, $t1, $t2                        # soma x
sll $v0, $t1, 2                          # multiplica por 4

jr $ra

# Subrotina para ler input do teclado
# Lê do endereço 0xffff0004 quando uma tecla é pressionada;
# Teclas: w: ↑; a: ←; s: ↓; d: →;
# Converte a tecla pressionada para direção,
# Salva a nova direção na memória e atualiza
# a cabeça se necessário (quando a direção muda)
# https://www.reddit.com/r/learnprogramming/comments/4fxr73/mips_understanding_memory_mapped_io_and_polling/
poll:
# se a flag RECEIVER_CTRL for 1, uma tecla foi pressionada
lw   $t0, RECEIVER_CTRL

beq  $t0, $zero, _returnPoll                  # se nenhuma tecla foi pressionada, pula

lbu  $a0, RECEIVER_DATA                       # lê a tecla

# código ASCII de cada tecla
beq  $a0, 0x77, _w
beq  $a0, 0x61, _a
beq  $a0, 0x73, _s
beq  $a0, 0x64, _d
j _pause                                      # qualquer tecla que não for wasd, pausa o jogo

_w:
move $t0, $zero                               #
ori  $t1, $zero, -1                           #
sb   $t0, dirX                                # salva nova dirX
sb   $t1, dirY                                # salva nova dirY
move $s0, COR_SNAKE_UP                        # carrega cor correta para atualizar a cabeça
j _atualizaCabeca

_a:
ori  $t0, $zero, -1
move $t1, $zero
sb   $t0, dirX
sb   $t1, dirY
move $s0, COR_SNAKE_LFT
j _atualizaCabeca

_s:
move $t0, $zero
ori  $t1, $zero, 1
sb   $t0, dirX
sb   $t1, dirY
move $s0, COR_SNAKE_DWN
j _atualizaCabeca

_d:
ori  $t0, $zero, 1
move $t1, $zero
sb   $t0, dirX
sb   $t1, dirY
move $s0, COR_SNAKE_RGHT 
j _atualizaCabeca

_pause:
j pause

_atualizaCabeca:
# quando muda a direção é necessário
# mudar a direção do pixel atual pra 
# apagar corretamente 
addi $sp, $sp, -4                         # aloca memória no stack
sw   $ra, 0($sp)                          # salva o return address

# carrega coords x e y da cabeça
lb $a0, headX
lb $a1, headY
jal converteXY                           # converte para endereço

la $t3, display                          # carrega endereço base do display
add $t3, $t3, $v0                        # soma endereços
sw $s0, 0($t3)                           # escreve a cor certa no endereço

lw $ra, 0($sp)                            # carrega o $ra
addiu $sp, $sp, 4                         # libera o stack

_returnPoll:
jr   $ra

# Subrotina para mover a snake
# move para a nova posição de acordo
# com a direção lida de dirX e dirY;
# verificação de colisões:
#  if (colisão com parede ou cobra) exit;
#  else if (colisão com comida) $s7 = 1, não apaga tail;
#  else apaga a tail;
move_:
addi $sp, $sp, -4                        # aloca memória no stack
sw   $ra, 0($sp)                         # salva o return address

# cor da nova posição
jal corDirecao
move $t5, $v0

# carrega direções x e y
lb   $t0, dirX
lb   $t1, dirY

# carrega coordenadas x e y
lb   $t2, headX
lb   $t3, headY

# calcula nova posição
add $a0, $t2, $t0
add $a1, $t3, $t1

sb $a0, headX
sb $a1, headY
jal converteXY

# verifica se a nova posição não é parede ou a própria cobra
la  $t7, display
add $t7, $t7, $v0
lw  $t7, 0($t7)                             # lê o pixel da nova posição
beq $t7, COR_COMIDA, _desenhaNovaComida     # se for comida, coloca 1 em $s7
bne $t7, COR_FUNDO, gameOver                  # se for diferente do fundo, game over
j _naoDesenhaComida

_desenhaNovaComida:
ori $s7, $zero, 1

_naoDesenhaComida:
move $s2, $t7                  # salva em $s2 para usar depois

# desenha a cabeça
ori $a0, $zero, 1
or  $a1, $zero, $v0
or  $a3, $zero, $t5
jal desenhaDisplay

# carrega coordenadas x e y da tail
lb   $a0, tailX
lb   $a1, tailY
jal  converteXY

# salva coordenadas
move $s0, $a0                            # tailX
move $s1, $a1                            # tailY
move $s2, $v0                            # salva endereço em $s2

beq $s7, 1, _naoApagaCauda

_apagaCauda:
# move $a0, $v0
la  $a0, display                         # endereço inicial do display
add $t7, $a0, $s2                        # adiciona ao endereço da tail
lw  $a0, 0($t7)                          # carrega conteúdo do endereço
srl $a0, $a0, 24                         # shift para a direita pra isolar o último byte
jal direcaoCauda                         # descobre a direção da cauda

add $s0, $s0, $v0                        # desloca tailX e tailY
add $s1, $s1, $v1                        # 
sb  $s0, tailX                           # salva na memória a nova posição da cauda
sb  $s1, tailY                           #

# apaga fim da cauda
ori $a0, $zero, 1
or  $a1, $zero, $s2
ori $a3, $zero, COR_FUNDO
jal desenhaDisplay

_naoApagaCauda:
lw $ra, 0($sp)                            # carrega o $ra
addiu $sp, $sp, 4                         # libera o stack

jr $ra


# Subrotina para descobrir a direção
# valor de retorno
#  $v0: direção (cor com último byte correspondendo à direção)
corDirecao:
lb   $t0, dirX
lb   $t1, dirY

bne  $t0, 0, _horizontal                 # if (x == 0) goto _horizontal

_vertical:
beq  $t1, 1, __down                      # if (y == 1) goto __down

__up:
move $v0, COR_SNAKE_UP
j _returnDir

__down:
move $v0, COR_SNAKE_DWN
j _returnDir


_horizontal:
beq  $t0, 1, __right                      # if (x == 1) goto __right

__left:
move $v0, COR_SNAKE_LFT
j _returnDir

__right:
move $v0, COR_SNAKE_RGHT
j _returnDir

_returnDir:
jr $ra

# Subrotina para descobrir a direção da tail
# args:
#  $a0: último byte do endereço
# valor de retorno
#  $v0: x
#  $v1: y
direcaoCauda:
beq $a0, 1, _dir_up                      # if ($a0 == 1) goto _dir_up
beq $a0, 2, _dir_right                   # if ($a0 == 2) goto _dir_right
beq $a0, 3, _dir_down                    # if ($a0 == 3) goto _dir_down
beq $a0, 4, _dir_left                    # if ($a0 == 4) goto _dir_left

_dir_up:
ori $v0, $zero, 0                        # direções de X e Y
ori $v1, $zero, -1
j _returnDirCauda

_dir_right:
ori $v0, $zero, 1
ori $v1, $zero, 0
j _returnDirCauda

_dir_down:
ori $v0, $zero, 0
ori $v1, $zero, 1
j _returnDirCauda

_dir_left:
ori $v0, $zero, -1
ori $v1, $zero, 0

_returnDirCauda:
jr $ra

# Subrotina para printar o score
printScore:
la $a0, gameOverStr1
li $v0, 4
syscall

move $a0, $t9
li   $v0, 1
syscall

la $a0, gameOverStr2
li $v0, 4
syscall

jr $ra
# ------------------------ SUBROTINAS ------------------------
