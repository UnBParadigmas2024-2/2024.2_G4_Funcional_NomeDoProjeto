{-# LANGUAGE PatternSynonyms #-}
module Main where


-- Assets do campo minado
-- https://github.com/BrandonDusseau/minesweeper-classic

-- Asset do botãp (UI Starter Pack)
-- https://pauboeg.itch.io/ui-starter-pack?download

import Control.Monad (forM_, foldM, when)  -- Adicionar 'when'
import Raylib.Core.Shapes (drawRectangle)  -- Para desenhar o retângulo
import Raylib.Core.Text (drawText)  -- Para desenhar texto
import Data.Time.Clock (getCurrentTime, diffUTCTime)
import Text.Printf (printf)

import Paths_CampoMinado (getDataFileName)
import Raylib.Core (clearBackground, isMouseButtonPressed, getMousePosition, getMouseX, getMouseY, setTargetFPS, initWindow, closeWindow, endDrawing, beginDrawing, isKeyPressed)
import Raylib.Core.Text (drawText)
import Raylib.Core.Textures
  ( drawTexturePro,
    loadImage,
    loadTextureFromImage
  )
import Raylib.Types (Rectangle (Rectangle, rectangle'height, rectangle'width), pattern Vector2, MouseButton (..), KeyboardKey (..), Color(..))
import Raylib.Util (drawing, whileWindowOpen_, withWindow, managed)
import Raylib.Util.Colors (black, white)

import Game
  ( gameInit
  , gameUpdate
  , state'grid
  , state'cnt
  , state'finished
  , state'win
  , state'lose
  , state'size
  , state'remainingBombs
  , state'remainingFlags
  , state'startTime
  , state'currentTime
  , state'structureType
  , printGrid
  , gameRestart
  , cellHasFlag
  )
import Node (Node(..), bomba)
import Grid (Grid)
import GHC.Generics (S)
import Raylib.Core.Text (drawText)

spriteError      :: Rectangle; spriteError      = (Rectangle (96)   (64) 16 16)
spriteVisited    :: Rectangle; spriteVisited    = (Rectangle (32) (83) 16 16)
spriteNotVisited :: Rectangle; spriteNotVisited = (Rectangle (50) (83) 16 16)
spriteBomb       :: Rectangle; spriteBomb       = (Rectangle (16*2) (21+16*2) 16 16)
spriteBombCount0 :: Rectangle; spriteBombCount0 = (Rectangle (32)   (84) 16 16)
spriteBombCount1 :: Rectangle; spriteBombCount1 = (Rectangle (16*0) (21+0) 16 16)
spriteBombCount2 :: Rectangle; spriteBombCount2 = (Rectangle (16*1) (21+0) 16 16)
spriteBombCount3 :: Rectangle; spriteBombCount3 = (Rectangle (16*2) (21+0) 16 16)
spriteBombCount4 :: Rectangle; spriteBombCount4 = (Rectangle (16*3) (21+0) 16 16)
spriteBombCount5 :: Rectangle; spriteBombCount5 = (Rectangle (16*0) (21+16) 16 16)
spriteBombCount6 :: Rectangle; spriteBombCount6 = (Rectangle (16*1) (21+16) 16 16)
spriteBombCount7 :: Rectangle; spriteBombCount7 = (Rectangle (16*2) (21+16) 16 16)
spriteBombCount8 :: Rectangle; spriteBombCount8 = (Rectangle (16*3) (21+16) 16 16)
spriteFlag       :: Rectangle; spriteFlag       = (Rectangle (16*1) (21+16*2) 16 16)

getRectForVisibleCellSprite :: Grid -> Int -> Int -> Rectangle
getRectForVisibleCellSprite grid row col = rect
  where
    isVisited   = visited (grid !! row !! col)
    bombsAround = dataNode (grid !! row !! col)
    flagSet = hasFlag (grid !! row !! col)
    rect
      | isVisited && bombsAround == bomba = spriteBomb
      | isVisited && bombsAround == 0 = spriteVisited
      | isVisited && bombsAround == 1 = spriteBombCount1
      | isVisited && bombsAround == 2 = spriteBombCount2
      | isVisited && bombsAround == 3 = spriteBombCount3
      | isVisited && bombsAround == 4 = spriteBombCount4
      | isVisited && bombsAround == 5 = spriteBombCount5
      | isVisited && bombsAround == 6 = spriteBombCount6
      | isVisited && bombsAround == 7 = spriteBombCount7
      | isVisited && bombsAround == 8 = spriteBombCount8
      | (not isVisited) && flagSet = spriteFlag
      | not isVisited = spriteNotVisited
      | otherwise     = spriteError

getRectForHiddenCellSprite :: Grid -> Int -> Int -> Rectangle
getRectForHiddenCellSprite grid row col = rect
  where
    bombsAround = dataNode (grid !! row !! col)
    rect
      | bombsAround == bomba = spriteBomb
      | bombsAround == 0 = spriteVisited
      | bombsAround == 1 = spriteBombCount1
      | bombsAround == 2 = spriteBombCount2
      | bombsAround == 3 = spriteBombCount3
      | bombsAround == 4 = spriteBombCount4
      | bombsAround == 5 = spriteBombCount5
      | bombsAround == 6 = spriteBombCount6
      | bombsAround == 7 = spriteBombCount7
      | bombsAround == 8 = spriteBombCount8
      | otherwise        = spriteError

formatTime :: Int -> String
formatTime seconds =
    let minutes = seconds `div` 60
        remainingSeconds = seconds `mod` 60
    in printf "%02d:%02d" minutes remainingSeconds

-- Define os tipos de telas
data Screen = SetStructureMenu | SetGridSizeMenu | SetDifficultyMenu | GameScreen deriving Eq

spritePath :: String
spritePath = "assets/sprite.gif"
buttonPath :: String
buttonPath = "assets/button.png"

main :: IO ()
main = do
  withWindow
    800
    800
    "Campo Minado"
    60
    ( \window -> do
        texture <- managed window $ loadTextureFromImage =<< loadImage =<< getDataFileName spritePath
        buttonTexture <- managed window $ loadTextureFromImage =<< loadImage =<< getDataFileName buttonPath

        let scale = 2 :: Float
        let spriteBombSize = (16 * round (scale)) :: Int
        let gridOffset = 100
        initialState <- gameInit 10 "easy" "bfs"
        let initialScreen = SetStructureMenu

        -- Controle da tela atual com estado encapsulado em uma tupla
        whileWindowOpen_ (\(state, screen) -> do
            case screen of
              SetStructureMenu -> do
                drawing $ do
                  clearBackground black
                  -- Configuração dos três botões
                  let buttonStructureWidth = 150
                      buttonStructureHeight = 75
                      buttonStructureSpacing = 20
                      buttonStructureY = 300
                      structureFontSize = 20
                  -- Configuração dos botões e seus respectivos parâmetros
                  let buttonStructureConfigs =
                        [ ("Fila", 250, "bfs")       -- Texto, Posição X, Estrutura desejada
                        , ("Pilha", 450, "dfs")
                        ]
                  -- Função auxiliar para desenhar o botão e detectar cliques
                  let drawAndCheckbuttonStructureClick (text, buttonStructureX, structure) = do
                        -- Posições para centralizar o texto no botão
                        let textSizeX = buttonStructureX + (buttonStructureWidth `div` 2) - (length text * structureFontSize `div` 4)
                            textSizeY = buttonStructureY + (buttonStructureHeight `div` 2) - (structureFontSize `div` 2)

                        -- Desenha o botão na posição especificada
                        drawTexturePro buttonTexture
                          (Rectangle 0 0 793 205)
                          (Rectangle (fromIntegral buttonStructureX) (fromIntegral buttonStructureY)
                                    (fromIntegral buttonStructureWidth) (fromIntegral buttonStructureHeight))
                          (Vector2 0 0) 0 white

                        -- Desenha o texto no botão
                        drawText text textSizeX textSizeY structureFontSize black

                        -- Verifica se o botão foi clicado
                        mouseStructureX <- getMouseX
                        mouseStructureY <- getMouseY
                        leftMouseStructureClicked <- isMouseButtonPressed MouseButtonLeft
                        let isbuttonStructureClicked = leftMouseStructureClicked &&
                              mouseStructureX >= buttonStructureX &&
                              mouseStructureX <= buttonStructureX + buttonStructureWidth &&
                              mouseStructureY >= buttonStructureY &&
                              mouseStructureY <= buttonStructureY + buttonStructureHeight

                        -- Se o botão foi clicado, inicia o jogo com o estado inicial
                        if isbuttonStructureClicked
                          then do
                            let updatedState = state { state'structureType = structure }
                            return (Just (updatedState, SetGridSizeMenu)) -- Retorna a próxima tela menu 
                          else return Nothing

                          -- Desenha cada botão e verifica cliques
                  result <- foldM (\acc btnConfig ->
                            case acc of
                              Just val -> return (Just val) -- Já encontrou o botão clicado
                              Nothing -> drawAndCheckbuttonStructureClick btnConfig)
                            Nothing buttonStructureConfigs

                  -- Decide o próximo estado com base na detecção de clique
                  case result of
                    Just gameState -> return gameState
                    Nothing -> return (state, SetStructureMenu) -- Se nenhum botão foi clicado, permanece no menu

              SetGridSizeMenu -> do
                drawing $ do
                  clearBackground black
                  -- Configuração dos três botões
                  let buttonSizeWidth = 150
                      buttonSizeHeight = 75
                      buttonSizeSpacing = 20
                      buttonSizeY = 300
                      sizeFontSize = 20
                  -- Configuração dos botões e seus respectivos parâmetros
                  let buttonSizeConfigs =
                        [ ("10x10", 100, 10)       -- Texto, Posição X, tamanho GRID"
                        , ("15x15", 300, 15)
                        , ("20x20", 500, 20)
                        ]
                  -- Função auxiliar para desenhar o botão e detectar cliques
                  let drawAndCheckButtonSizeClick (text, buttonSizeX, gridSize) = do
                        -- Posições para centralizar o texto no botão
                        let textSizeX = buttonSizeX + (buttonSizeWidth `div` 2) - (length text * sizeFontSize `div` 4)
                            textSizeY = buttonSizeY + (buttonSizeHeight `div` 2) - (sizeFontSize `div` 2)

                        -- Desenha o botão na posição especificada
                        drawTexturePro buttonTexture
                          (Rectangle 0 0 793 205)
                          (Rectangle (fromIntegral buttonSizeX) (fromIntegral buttonSizeY)
                                    (fromIntegral buttonSizeWidth) (fromIntegral buttonSizeHeight))
                          (Vector2 0 0) 0 white

                        -- Desenha o texto no botão
                        drawText text textSizeX textSizeY sizeFontSize black

                        -- Verifica se o botão foi clicado
                        mouseSizeX <- getMouseX
                        mouseSizeY <- getMouseY
                        leftMouseSizeClicked <- isMouseButtonPressed MouseButtonLeft
                        let isButtonSizeClicked = leftMouseSizeClicked &&
                              mouseSizeX >= buttonSizeX &&
                              mouseSizeX <= buttonSizeX + buttonSizeWidth &&
                              mouseSizeY >= buttonSizeY &&
                              mouseSizeY <= buttonSizeY + buttonSizeHeight

                        -- Se o botão foi clicado, inicia o jogo com o estado inicial
                        if isButtonSizeClicked
                          then do
                            let updatedState = state { state'size = gridSize }
                            return (Just (updatedState, SetDifficultyMenu)) -- Retorna a próxima tela menu 
                          else return Nothing

                  -- Desenha cada botão e verifica cliques
                  result <- foldM (\acc btnConfig ->
                            case acc of
                              Just val -> return (Just val) -- Já encontrou o botão clicado
                              Nothing -> drawAndCheckButtonSizeClick btnConfig)
                            Nothing buttonSizeConfigs

                  -- Decide o próximo estado com base na detecção de clique
                  case result of
                    Just gameState -> return gameState
                    Nothing -> return (state, SetGridSizeMenu) -- Se nenhum botão foi clicado, permanece no menu


              SetDifficultyMenu -> do
                drawing $ do
                  clearBackground black
                  -- Configuração dos três botões
                  let buttonWidth = 150
                      buttonHeight = 75
                      buttonSpacing = 20
                      buttonY = 300
                      fontSize = 20
                  -- Configuração dos botões e seus respectivos parâmetros
                  let buttonConfigs =
                        [ ("Easy", 100, "easy")       -- Texto, Posição X, Dificuldade"
                        , ("Normal", 300, "normal")
                        , ("Hard", 500, "hard")
                        ]
                  -- Função auxiliar para desenhar o botão e detectar cliques
                  let drawAndCheckButtonClick (text, buttonX, difficulty) = do
                        -- Posições para centralizar o texto no botão
                        let textX = buttonX + (buttonWidth `div` 2) - (length text * fontSize `div` 4)
                            textY = buttonY + (buttonHeight `div` 2) - (fontSize `div` 2)

                        -- Desenha o botão na posição especificada
                        drawTexturePro buttonTexture
                          (Rectangle 0 0 793 205)
                          (Rectangle (fromIntegral buttonX) (fromIntegral buttonY)
                                    (fromIntegral buttonWidth) (fromIntegral buttonHeight))
                          (Vector2 0 0) 0 white

                        -- Desenha o texto no botão
                        drawText text textX textY fontSize black

                        -- Verifica se o botão foi clicado
                        mouseX <- getMouseX
                        mouseY <- getMouseY
                        leftMouseClicked <- isMouseButtonPressed MouseButtonLeft
                        let isButtonClicked = leftMouseClicked &&
                              mouseX >= buttonX &&
                              mouseX <= buttonX + buttonWidth &&
                              mouseY >= buttonY &&
                              mouseY <= buttonY + buttonHeight

                        -- Se o botão foi clicado, inicia o jogo com o estado inicial
                        if isButtonClicked
                          then do
                            let gridSize = state'size state
                            let structure = state'structureType state
                            initialState <- gameInit gridSize difficulty structure
                            return (Just (initialState, GameScreen)) -- Retorna o estado do jogo e tela
                          else return Nothing

                  -- Desenha cada botão e verifica cliques
                  result <- foldM (\acc btnConfig ->
                            case acc of
                              Just val -> return (Just val) -- Já encontrou o botão clicado
                              Nothing -> drawAndCheckButtonClick btnConfig)
                            Nothing buttonConfigs

                  -- Decide o próximo estado com base na detecção de clique
                  case result of
                    Just gameState -> return gameState
                    Nothing -> return (state, SetDifficultyMenu) -- Se nenhum botão foi clicado, permanece no menu

              GameScreen -> do
                -- 1. Input
                leftButtonClicked <- isMouseButtonPressed MouseButtonLeft
                rightButtonClicked <- isMouseButtonPressed MouseButtonRight
                let mouseClicked = leftButtonClicked || rightButtonClicked
                (mouseX, mouseY) <- (\(Vector2 x y) -> (floor x, floor y)) <$> getMousePosition

                let col = (mouseX - gridOffset) `div` spriteBombSize
                    row = (mouseY - gridOffset) `div` spriteBombSize
                    validClick = mouseClicked && row >= 0 && col >= 0 &&
                                row < length (state'grid state) &&
                                col < length (head (state'grid state)) &&
                                (state'remainingFlags state > 0 || not rightButtonClicked || cellHasFlag (state'grid state) row col)

                 -- Atualizar o tempo se o jogo não acabou

                currentTime <- if state'finished state
                                    then return (state'currentTime state)
                                    else do
                                        currentTimeUTC <- getCurrentTime
                                        return $ floor $ diffUTCTime currentTimeUTC (state'startTime state)

                let stateWithTime = state { state'currentTime = currentTime }

            -- Verificar clique no botão de reiniciar
                let buttonX = 250
                    buttonY = 20
                    buttonWidth = 100
                    buttonHeight = 30
                    restartButtonArea = (mouseX >= buttonX && mouseX <= buttonX + buttonWidth) &&
                                  (mouseY >= buttonY && mouseY <= buttonY + buttonHeight)
                    clickedRestartButton = mouseClicked && restartButtonArea &&
                                     state'finished state

                let menuButtonX = 370
                    menuButtonY = 20
                    menuButtonWidth = 150
                    menuButtonHeight = 30
                    menuButtonArea = (mouseX >= menuButtonX && mouseX <= menuButtonX + menuButtonWidth) && (mouseY >= menuButtonY && mouseY <= menuButtonY + menuButtonHeight)
                    clickedMenuButton = mouseClicked && menuButtonArea && state'finished state

                -- 2. Atualizar jogo
                newState <- if clickedRestartButton
                            then gameRestart stateWithTime
                            else if clickedMenuButton
                              then return stateWithTime
                            else if state'finished stateWithTime
                                then return stateWithTime
                                else if validClick
                                    then gameUpdate stateWithTime row col rightButtonClicked
                                    else return stateWithTime

                let newScreen = if clickedMenuButton then SetStructureMenu else GameScreen

                when validClick $ do
                  -- printGrid (state'grid newState)
                  putStrLn $ "-------------------------- "
                  putStrLn $ "Remaining bombs: " ++ show (state'remainingBombs newState)
                  putStrLn $ "       Finished: " ++ show (state'finished newState)
                  putStrLn $ "           Lose: " ++ show (state'lose newState)
                  putStrLn $ "            Cnt: " ++ show (state'cnt newState)
                  -- FIXME: condição para você ganhou está sempre considerando vitória
                  if (state'cnt newState) == (state'win newState) then
                    putStrLn "               Voce ganhou!!"
                    -- TODO: revelar grid final?
                  else if (state'lose newState) then
                    putStrLn "               Voce perdeu!!"
                    -- TODO: revelar grid final
                    -- TODO: impedir que o jogo continue sendo jogado
                    -- TODO: reiniciar jogo?
                  else
                    putStrLn "                Game running"

                drawing
                  ( do
                    clearBackground black
                    -- Renderizar o contador de tempo
                    let timeStr = formatTime (state'currentTime newState)
                    let timerX = 20
                    let timerY = 20
                    let timerWidth = 120
                    let timerHeight = 40
                    let fontSize = 30

                    -- Fundo do timer
                    drawRectangle timerX timerY timerWidth timerHeight white
                    -- Texto do timer
                    drawText timeStr (timerX + 15) (timerY + 10) fontSize black

                    -- Quantidade de bombas
                    let bombsQty = show (state'remainingFlags state)  -- Convertendo para String com 'show'
                    let bombsQtyX = 700
                    let bombsQtyY = 20
                    let bombsQtyWidth = 120
                    let bombsQtyHeight = 40
                    let bombsQtyFontSize = 30

                    -- Fundo do contador de bombas
                    drawRectangle bombsQtyX bombsQtyY bombsQtyWidth bombsQtyHeight white

                    -- Desenhar a sprite da bandeira no HUD
                    drawTexturePro texture spriteFlag
                        (Rectangle (695) (28) (rectangle'width spriteFlag * 2) (rectangle'height spriteFlag * 2))
                        (Vector2 0 0) 0 white

                    -- Texto do bombsQty
                    drawText bombsQty (bombsQtyX + 30) (bombsQtyY + 10) bombsQtyFontSize black

                    -- Campo visível
                    forM_ (zip [0..] (state'grid newState)) $ \(rowIndex, rowList) ->
                      forM_ (zip [0..] rowList) $ \(colIndex, cell) -> do
                        let x = fromIntegral (gridOffset + (colIndex * spriteBombSize)) :: Float
                            y = fromIntegral (gridOffset + (rowIndex * spriteBombSize)) :: Float
                            rect = getRectForVisibleCellSprite (state'grid newState) rowIndex colIndex
                            rectHd = getRectForHiddenCellSprite (state'grid newState) rowIndex colIndex
                            isVisited = visited cell
                            isBomb = dataNode cell == bomba

                        if isVisited || (isBomb && state'finished newState) then
                            drawTexturePro texture spriteVisited
                                (Rectangle x y ((rectangle'width spriteVisited) * scale)
                                ((rectangle'height spriteVisited) * scale))
                                (Vector2 0 0) 0 white
                        else
                            drawTexturePro texture spriteNotVisited
                                (Rectangle x y ((rectangle'width spriteNotVisited) * scale)
                                ((rectangle'height spriteNotVisited) * scale))
                                (Vector2 0 0) 0 white

                        if state'finished newState then
                            drawTexturePro texture rectHd
                                (Rectangle x y ((rectangle'width rectHd) * scale)
                                ((rectangle'height rectHd) * scale))
                                (Vector2 0 0) 0 white
                        else
                            drawTexturePro texture rect
                                (Rectangle x y ((rectangle'width rect) * scale)
                                ((rectangle'height rect) * scale))
                                (Vector2 0 0) 0 white

                    -- Qd o jogo termina
                    when (state'finished newState) $ do
                      drawRectangle buttonX buttonY buttonWidth buttonHeight white
                      drawText "Reiniciar" (buttonX + 10) (buttonY + 8) 20 black

                      drawRectangle menuButtonX menuButtonY menuButtonWidth menuButtonHeight white
                      drawText "Menu Inicial" (menuButtonX + 15) (menuButtonY + 8) 20 black

                      let
                        screenWidth = 350
                        screenHeight = 180
                        centerX = (fromIntegral screenWidth :: Float) / 2.0 + 50
                        centerY = (fromIntegral screenHeight :: Float) / 2.0 + 100
                        buttonX = round (centerX + 50)
                        buttonY = round (centerY + 80)
                        buttonWidth = 100
                        buttonHeight = 40
                        centerXInt = round centerX
                        centerYInt = round centerY
                      if (state'cnt newState) == (state'win newState)
                        then do
                          drawRectangle centerXInt centerYInt screenWidth screenHeight (Color 200 255 200 180)
                          drawText "Ganhou!!" (centerXInt + 100) (centerYInt + 80) 30 (Color 0 128 0 255)
                        else when (state'lose newState) $ do
                          drawRectangle centerXInt centerYInt screenWidth screenHeight (Color 255 200 200 180)
                          drawText "Perdeu!!" (centerXInt + 100) (centerYInt + 80) 30 (Color 139 0 0 255)

                    -- Campo invisível, debug apenas
                    {-forM_ (zip [0..] (state'grid newState)) $ \(rowIndex, rowList) -> 
                        forM_ (zip [0..] rowList) $ \(colIndex, _) -> 
                          ( do
                              let x = fromIntegral (800 + (colIndex * spriteBombSize)) :: Float
                                  y = fromIntegral (100 + (rowIndex * spriteBombSize)) :: Float
                                  rect = getRectForHiddenCellSprite (state'grid newState) rowIndex colIndex
                              
                              -- if not visited
                              drawTexturePro texture spriteVisited 
                                (Rectangle x y ((rectangle'width (spriteVisited))*scale) 
                                ((rectangle'height (spriteVisited))*scale)) 
                                (Vector2 0 0) 0 white

                              drawTexturePro texture rect 
                                (Rectangle x y ((rectangle'width (rect))*scale) 
                                ((rectangle'height (rect))*scale)) 
                                (Vector2 0 0) 0 white
                          )-}
                  )
                return (newState, newScreen)
          )
          (initialState, initialScreen)
    )

