# Materiály k diplomové práci na téma "Možnosti využití strojového učení při detekci aktivit tvůrců trhu"

Základním požadavkem je Node.js v22.15.0 LTS, terminál MetaTrader 4 od ICMarkets (EU) Ltd. a internetový prohlížeč ideálně založený na internetovém prohléžeči chromium (Google Chrome, Microsoft Edge, Opera atd...). Dále je potřeba v platformě MetaTrader 4 umožnit import DLL (v platformě MetaTrader 4 vybrat Tools -> Options -> zaškrtnout Allow DLL imports), jelikož kódy využívají knihovnu WinINet.

## Generate Dataset

V této složce se nachází generátor datových sad pro učení modelů strojového učení. 
Najdeme zde Node.js server (server.js) a skripty, včetně šablon do platformy MetaTrader 4. 

Pro spuštění je potřeba:

1. Otevřít příkazový řádek ve složce se souborem server.js a provést příkaz npm install.
2. Po dokončení npm install provést příkaz node server.js.
3. V platformě MetaTrader 4 si otevřít Data Folder (File -> Open Data Folder) a přesunout sem MQL4 a Templates.
4. Následně v okně Navigator najít Scripts a pravým klikem na Scripts vybrat Refresh. Tento krok zkompiluje zdrojové kódy.
5. Vytvořit supporty a rezistance na grafu pomocí skriptu #DrawLines
6. Vyznačit úspěšné a neúspěšné pinbary pomocí skriptů #FailedPinBarDetector a #SuccessfulPinBarDetector (jsou přiloženy i šablony, které lze na graf aplikovat pravým klikem -> Template -> Vybrat např. EURUSD1999-2024 pro pár EURUSD M5).
7. Spustit skript #nodeJS_SendHistory_Close_Volume pro odeslání dat do Node.js, který z dat vytvoří datovou sadu. U vstupních parametrů vybrat požadovanou hodnotu barsInHistory, coz je počet vzorků.

V okně Navigator se pod Scripts následně objeví #ClearLines, #DrawLines, #FailedPinBarDetector, #SuccessfulPinBarDetector a #nodeJS_SendHistory_Close_Volume.

#ClearLines - Vymaže všechny supporty a rezistance vygenerované pomocí #DrawLines.

#DrawLines - Vytvoří supporty a rezistance na základě dvou ručne vytvořených horizontálních čar na grafu (je potřeba nakreslit na graf rozsah supportů a rezistencí na graf pomocí volby Draw horizontal line a poté spustit skript #DrawLines).

#FailedPinBarDetector - Označí neúspěšné pinbary na grafu podle nastaveného časového rozsahu (na základě předem vytvořených supportů a rezistencí).

#SuccessfulPinBarDetector - Stejně jako u #FailedPinBarDetector, ale s tím rozdílem, že označí úspěšné pinbary na grafu podle nastaveného časového rozsahu (na základě předem vytvořených supportů a rezistencí).

#nodeJS_SendHistory_Close_Volume - Odešle data do node.js server, který z těchto dat vytvoří datové sady pro učení modelů strojového učení.

## NN Evaluation

V této složce se nachází automatický obchodní systém (AOS) pro platformu MetaTrader 4 a Node.js server. Obojí slouží k ověření výkonnosti naučených modelů.

Pro spuštění je potřeba:

1. Otevřít příkazový řádek ve složce se souborem server.js (NN Evaluation/Server) a provést příkaz npm install.
2. Po dokončení npm install provést příkaz node server.js.
3. V platformě MetaTrader 4 si otevřít Data Folder (File -> Open Data Folder) a přesunout sem MQL4 a Templates.
4. Následně v okně Navigator najít Expert Advisors a pravým klikem na Scripts vybrat Refresh. Tento krok zkompiluje zdrojové kódy.
5. Vygenerovat vyznačit úspěšné a neúspěšné pinbary pomocí skriptů #FailedPinBarDetector a #SuccessfulPinBarDetector (viz. postup u Generate Dataset) pro model neznámý časový rozsah a uložit jako šablonu (pravým kliknutím na graf -> Template -> Save template, případně v testeru strategií načíst šablonu jako je např. EURUSD2024-2025 pro EURUSD M5.
6. Otevřít tester strategií (Strategy tester) pomocí klávesové zkratky CTRL+R a zaškrnout Visual Mode. Posuvník vedle Visual Mode přesunout na hodnotu 1. Dále je potřeba zaškrtnout Use date tak, aby odpovídalo požadovanému časovému rozsahu (v případe použití šablony EURUSD2024-2025 vybrat From 2024.01.01 To 2025.01.01. U period vybrat M5, u model vybrat Open prices only a symbol vybrat EURUSD. Také je potřeba vybrat v Expert properties požadovanou hodnotu Number of bars to analyze, což je počet vzorků.
7. Pro spuštení vyhodnocení kliknout na tlačítko Start v pravém dolním rohu. Otevře se nové okno s grafem, kde je potřeba načíst šablonu z kroku č. 5. Poté je možné posunout posuvník vedle Visual mode na hodnotu 32 pro zrychlení průběhu vyhodnocování.
8. Po dokončení je ve složce (např. Server/EURUSDM5/10 Bars) vytvořen soubor predictions_log.json, který obsahuje jednotlivé predikce a celkovou přesnost modelu.
9. Pro optimalizaci prahových hodnot je možné využit skript analyze_all.js pomocí příkazu v příkazové řádce node analyze_all.js, který je ve složce se souborem server.js. Skript provede analýzu prahových hodnot a vypíše nejvhodnější prahovou hodnotu.

## NN Learning

V této složce se nachází materiály pro učení modelů a grafy s výsledky.
Pro zjednodušení byly vytvořeny HTML soubory, pomocí kterých lze učit modely přímo v prohlížeči.

Pro spuštění je potřeba:
1. Vybrat si složku s párem a počtem vzorků (např. /EURUSDM5/10 Bars/).
2. Spustit index.html. Otevře se GUI pro učení modelů.
3. Vybrat backend (WebGPU, WebGL, CPU) a kliknout na tlačítko Initialize Backend.
4. Pro spuštění učení modelu kliknout na Start Training.
5. Po dokončení učení se napravo zobrazí metriky z učení modelu. Následně je možné pomocí tlačítka Save model uložit naučený model a použít ho u NN Evaluation (viz. předchozí složka).
6. Na konci stránky jsou zobrazeny plot.ly grafy, které je možné uložit pomocí tlačítka na uložení grafu (pravý horní roh grafu). 

## Řešení problémů

V případě chyby ERR_DLOPEN_FAILED na OS Windows, při spouštění serveru pomocí příkazu node server.js, je potřeba ručně zkopírovat tensorflow.dll ze složky node_modules\@tensorflow\tfjs-node\deps\lib\ do node_modules\@tensorflow\tfjs-node\lib\napi-v8\. 
Pokud tensorflow.dll chybí úplně, je potřeba nejprve nainstalovat Visual Studio Build Tools 2022 pomocí chocolatey: 
choco install visualstudio2022buildtools
a poté provést následující příkazy:
npm uninstall @tensorflow/tfjs-node
npm cache clean --force
npm install -g node-gyp
npm install @tensorflow/tfjs-node

