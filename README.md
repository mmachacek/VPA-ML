# Materiály k diplomové práci na téma "Možnosti využití strojového učení při detekci aktivit tvůrců trhu"

Základním požadavkem je Node.js v22.15.0 LTS, terminál MetaTrader 4 od ICMarkets (EU) Ltd. a internetový prohlížeč ideálně založený na internetovém prohléžeči chromium (Google Chrome, Microsoft Edge, Opera atd...)

## Generate Dataset

V této složce se nachází generátor datových sad pro učení modelů strojového učení. 
Najdeme zde Node.js server (server.js) a skripty, včetně šablon do platformy MetaTrader 4. 

Pro spuštění je potřeba:

1. Otevřít příkazový řádek ve složce se souborem server.js a provést příkaz npm install.
2. Po dokončení npm install provést příkaz node server.js.
3. V platformě MetaTrader 4 si otevřít Data Folder (File -> Open Data Folder) a přesunout sem MQL4 a Templates.
4. Následně v okně Navigator najít Scripts a pravým klikem na Scripts vybrat Refresh. Tento krok zkompiluje zdrojové kódy.
5. Vytvořit supporty a rezistance na grafu pomocí skriptu #DrawLines
6. Vyznačit úspěšné a neúspěšné pinbary pomocí skriptů #FailedPinBarDetector a #SuccessfulPinBarDetector.
7. Spustit skript #nodeJS_SendHistory_Close_Volume pro odeslání dat do Node.js, který z dat vytvoří datovou sadu.

V okně Navigator se pod Scripts následně objeví #ClearLines, #DrawLines, #FailedPinBarDetector, #SuccessfulPinBarDetector a #nodeJS_SendHistory_Close_Volume.

#ClearLines - Vymaže všechny supporty a rezistance vygenerované pomocí #DrawLines.

#DrawLines - Vytvoří supporty a rezistance na základě dvou ručne vytvořených horizontálních čar na grafu (je potřeba nakreslit na graf rozsah supportů a rezistencí na graf pomocí volby Draw horizontal line a poté spustit skript #DrawLines).

#FailedPinBarDetector - Označí neúspěšné pinbary na grafu podle nastaveného časového rozsahu (na základě předem vytvořených supportů a rezistencí).

#SuccessfulPinBarDetector - Stejně jako u #FailedPinBarDetector, ale s tím rozdílem, že označí úspěšné pinbary na grafu podle nastaveného časového rozsahu (na základě předem vytvořených supportů a rezistencí).

#nodeJS_SendHistory_Close_Volume - Odešle data do node.js server, který z těchto dat vytvoří datové sady pro učení modelů strojového učení.

## NN Evaluation

## NN Learning

## Řešení problémů

V případě chyby ERR_DLOPEN_FAILED na OS Windows, při spouštění serveru pomocí příkazu node server.js, je potřeba ručně zkopírovat tensorflow.dll ze složky node_modules\@tensorflow\tfjs-node\deps\lib\ do node_modules\@tensorflow\tfjs-node\lib\napi-v8\. 
Pokud tensorflow.dll chybí úplně, je potřeba nejprve nainstalovat Visual Studio Build Tools 2022 pomocí chocolatey: 
choco install visualstudio2022buildtools
a poté provést následující příkazy:
npm uninstall @tensorflow/tfjs-node
npm cache clean --force
npm install -g node-gyp
npm install @tensorflow/tfjs-node

