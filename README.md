# 🎮 Projeto Arduino – Sistema de Acerto e Erro com LEDs

## 📌 Visão Geral

Este projeto utiliza a plataforma **Arduino** para implementar um sistema interativo baseado em **botões e LEDs**, no qual o usuário realiza uma entrada e o sistema responde visualmente indicando **acerto ou erro**. O projeto foi desenvolvido com foco educacional, integrando conceitos de eletrônica básica, lógica de programação e sistemas embarcados.

---

## 🧠 Funcionamento do Sistema

* O usuário interage com o sistema por meio de **botões push-button**.
* Cada botão corresponde a uma possível entrada.
* O Arduino lê o sinal digital e compara com a lógica definida no código.
* **Acerto:** o sistema executa uma **animação visual** com os LEDs.
* **Erro:** todos os **quatro LEDs acendem simultaneamente**, indicando a resposta incorreta.

O sistema opera em execução contínua, permitindo múltiplas interações.

---

## 🔌 Circuito

O circuito foi montado utilizando:

* Placa **Arduino Uno**
* Protoboard
* LEDs com resistores limitadores de corrente
* Botões push-button com resistores de pull-up ou pull-down

O circuito foi inicialmente validado por meio do **SimulIDE** e posteriormente montado fisicamente.

📷 *Imagem do circuito disponível no repositório.*

---

## 💻 Código

O código foi desenvolvido em **C/C++**, utilizando a **IDE do Arduino**. Ele é responsável por:

* Configurar pinos de entrada e saída
* Ler o estado dos botões
* Controlar os LEDs conforme a lógica de acerto e erro
* Executar animações visuais

O código está comentado para facilitar o entendimento e a manutenção.

---

## 📂 Estrutura do Repositório

```
├── codigo/          # Código-fonte Arduino (.ino)
├── circuito/        # Arquivo do circuito no SimulIDE (.sim1)
├── imagens/         # Imagens do circuito
└── README.md        # Documentação do projeto
```

---

## 🚀 Tecnologias Utilizadas

* Arduino Uno
* Linguagem C/C++
* SimulIDE
* Protoboard e componentes eletrônicos

---

## 🎯 Objetivo Educacional

Este projeto tem como objetivo reforçar conceitos de:

* Entradas e saídas digitais
* Leitura de sinais elétricos
* Controle de LEDs
* Estruturas condicionais na programação

---

## 📄 Licença

Este projeto é destinado a fins educacionais e acadêmicos.

---

✨ Desenvolvido para aprendizado e prática em eletrônica e programação embarcada.
