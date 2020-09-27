# Pancakes

A system for enabling users who are both long ETH to trade off risk with profits

- [Pancakes](#pancakes)
  - [Development](#development)
  - [What is it](#what-is-it)
  - [More information](#more-information)

## Development

See the README in the `frontend` folder for instructions on running the app locally. Contracts are located in the `contracts` folder

## What is it

When you invest in ETH, or any other token, the value fluctuates; this is known as market risk. Sometimes, investors are okay with this risk, especially because risk is usually accompanied higher returns, but other times, when investors need liquidity or stability, the risk can be concerning. Pancakes is a way for investors all of whom are long on ETH to swap returns for decreased risk and volatility. 

Pancakes creates a way for more conservative investors (investors in the Buttermilk token, BUTTR) to give up all of their returns above a targeted fixed rate to more aggressive investors (investors in the Chocolate Chip token, CHOCO) in exchange for stability:

- When ETH appreciates in value, everyone makes money, but some of the money that BUTTR holders would have earned goes to CHOCO holders
- When ETH loses value, all losses are absorbed by CHOCO holders first. It is only when CHOCO loses all its value that BUTTR tokens start to lose value.

In other words, when ETH is doing well, everyone makes money and CHOCO holders make a lot, but when the market goes down, the losses are primarily absorbed by CHOCO holders, keeping BUTTR intact.

## More information

- [Devpost submission](https://devpost.com/software/pancakes-f54xg9)
- [Youtube video](https://youtu.be/xCa3CTEtLt8)
