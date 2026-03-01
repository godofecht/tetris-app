import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

void main() {
  runApp(const TetrisApp());
}

class TetrisApp extends StatelessWidget {
  const TetrisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tetris',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1a1a2e),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
      ),
      home: const TetrisGame(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class TetrisGame extends StatefulWidget {
  const TetrisGame({super.key});

  @override
  State<TetrisGame> createState() => _TetrisGameState();
}

class _TetrisGameState extends State<TetrisGame> {
  static const int rows = 20;
  static const int cols = 10;
  static const double blockSize = 30.0;

  List<List<Color?>> board = [];
  Tetromino? currentPiece;
  Tetromino? nextPiece;
  int score = 0;
  int level = 1;
  int linesCleared = 0;
  bool gameOver = false;
  bool isPaused = false;
  Timer? gameTimer;
  Duration dropInterval = const Duration(milliseconds: 800);

  final Random random = Random();

  // Tetromino shapes - simplified without rotation states
  final List<List<Offset>> tetrominoes = [
    [Offset(0, 0), Offset(1, 0), Offset(2, 0), Offset(3, 0)], // I
    [Offset(0, 0), Offset(1, 0), Offset(0, 1), Offset(1, 1)], // O
    [Offset(0, 0), Offset(1, 0), Offset(2, 0), Offset(1, 1)], // T
    [Offset(1, 0), Offset(2, 0), Offset(0, 1), Offset(1, 1)], // S
    [Offset(0, 0), Offset(1, 0), Offset(1, 1), Offset(2, 1)], // Z
    [Offset(0, 0), Offset(0, 1), Offset(1, 1), Offset(2, 1)], // J
    [Offset(2, 0), Offset(0, 1), Offset(1, 1), Offset(2, 1)], // L
  ];

  // Rotation transformations
  List<Offset> rotatePiece(List<Offset> shape) {
    return shape.map((b) => Offset(-b.dy, b.dx)).toList();
  }

  final List<Color> colors = [
    Colors.cyan,    // I
    Colors.yellow,  // O
    Colors.purple,  // T
    Colors.green,   // S
    Colors.red,     // Z
    Colors.blue,    // J
    Colors.orange,  // L
  ];

  @override
  void initState() {
    super.initState();
    initBoard();
    startGame();
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    super.dispose();
  }

  void initBoard() {
    board = List.generate(rows, (_) => List.filled(cols, null));
  }

  void startGame() {
    initBoard();
    score = 0;
    level = 1;
    linesCleared = 0;
    gameOver = false;
    isPaused = false;
    dropInterval = const Duration(milliseconds: 800);
    currentPiece = createRandomPiece();
    nextPiece = createRandomPiece();
    startTimer();
  }

  Tetromino createRandomPiece() {
    int index = random.nextInt(tetrominoes.length);
    return Tetromino(
      baseShape: tetrominoes[index],
      color: colors[index],
      x: 3,
      y: 0,
    );
  }

  void startTimer() {
    gameTimer?.cancel();
    gameTimer = Timer.periodic(dropInterval, (_) {
      if (!gameOver && !isPaused) {
        moveDown();
      }
    });
  }

  void moveDown() {
    if (currentPiece == null) return;
    
    setState(() {
      currentPiece!.y++;
      if (checkCollision()) {
        currentPiece!.y--;
        lockPiece();
        clearLines();
        spawnPiece();
      }
    });
  }

  void moveLeft() {
    if (gameOver || isPaused || currentPiece == null) return;
    setState(() {
      currentPiece!.x--;
      if (checkCollision()) {
        currentPiece!.x++;
      }
    });
  }

  void moveRight() {
    if (gameOver || isPaused || currentPiece == null) return;
    setState(() {
      currentPiece!.x++;
      if (checkCollision()) {
        currentPiece!.x--;
      }
    });
  }

  void rotate() {
    if (gameOver || isPaused || currentPiece == null) return;
    setState(() {
      List<Offset> prevShape = List.from(currentPiece!.currentShape);
      currentPiece!.rotate();
      if (checkCollision()) {
        // Wall kick - try moving left or right
        currentPiece!.x--;
        if (checkCollision()) {
          currentPiece!.x += 2;
          if (checkCollision()) {
            currentPiece!.x--;
            currentPiece!.currentShape = prevShape;
          }
        }
      }
    });
  }

  void hardDrop() {
    if (gameOver || isPaused || currentPiece == null) return;
    setState(() {
      while (!checkCollision()) {
        currentPiece!.y++;
      }
      currentPiece!.y--;
      lockPiece();
      clearLines();
      spawnPiece();
    });
  }

  bool checkCollision() {
    if (currentPiece == null) return false;
    
    List<Offset> blocks = currentPiece!.getBlocks();
    for (Offset block in blocks) {
      int newX = currentPiece!.x + block.dx.toInt();
      int newY = currentPiece!.y + block.dy.toInt();
      
      if (newX < 0 || newX >= cols || newY >= rows) {
        return true;
      }
      if (newY >= 0 && board[newY][newX] != null) {
        return true;
      }
    }
    return false;
  }

  void lockPiece() {
    if (currentPiece == null) return;
    
    List<Offset> blocks = currentPiece!.getBlocks();
    for (Offset block in blocks) {
      int x = currentPiece!.x + block.dx.toInt();
      int y = currentPiece!.y + block.dy.toInt();
      if (y >= 0 && y < rows && x >= 0 && x < cols) {
        board[y][x] = currentPiece!.color;
      }
    }
  }

  void clearLines() {
    int lines = 0;
    for (int i = rows - 1; i >= 0; i--) {
      if (board[i].every((cell) => cell != null)) {
        board.removeAt(i);
        board.insert(0, List.filled(cols, null));
        lines++;
        i++;
      }
    }
    
    if (lines > 0) {
      setState(() {
        linesCleared += lines;
        score += [0, 100, 300, 500, 800][lines] * level;
        level = (linesCleared / 10).floor() + 1;
        dropInterval = Duration(milliseconds: max(100, 800 - (level - 1) * 100));
      });
      startTimer();
    }
  }

  void spawnPiece() {
    setState(() {
      currentPiece = nextPiece;
      nextPiece = createRandomPiece();
      
      if (checkCollision()) {
        gameOver = true;
        gameTimer?.cancel();
      }
    });
  }

  void togglePause() {
    setState(() {
      isPaused = !isPaused;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tetris'),
        centerTitle: true,
        backgroundColor: const Color(0xFF16213e),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Score and stats
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  buildStatBox('Score', '$score'),
                  buildStatBox('Level', '$level'),
                  buildStatBox('Lines', '$linesCleared'),
                ],
              ),
            ),
            // Game area
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Main game board
                  GestureDetector(
                    onTap: () => hardDrop(),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white30, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: CustomPaint(
                        size: Size(cols * blockSize, rows * blockSize),
                        painter: BoardPainter(board, currentPiece, blockSize),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Next piece and controls
                  Column(
                    children: [
                      // Next piece preview
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white30),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            const Text('NEXT', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: 120,
                              height: 120,
                              child: CustomPaint(
                                painter: NextPiecePainter(nextPiece, 25),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Control buttons
                      ElevatedButton(
                        onPressed: togglePause,
                        child: Text(isPaused ? 'Resume' : 'Pause'),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: startGame,
                        child: const Text('Restart'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Mobile controls
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.rotate_left, size: 40),
                    onPressed: rotate,
                    iconSize: 40,
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_left, size: 40),
                        onPressed: () => moveLeft(),
                        iconSize: 40,
                      ),
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down, size: 40),
                        onPressed: () => moveDown(),
                        iconSize: 40,
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_right, size: 40),
                        onPressed: () => moveRight(),
                        iconSize: 40,
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.keyboard_double_arrow_down, size: 40),
                    onPressed: hardDrop,
                    iconSize: 40,
                  ),
                ],
              ),
            ),
            // Game over overlay
            if (gameOver)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'GAME OVER',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Final Score: $score',
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: startGame,
                        child: const Text('Play Again'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget buildStatBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF16213e),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class Tetromino {
  final List<Offset> baseShape;
  List<Offset> currentShape;
  final Color color;
  int x, y;

  Tetromino({
    required this.baseShape,
    required this.color,
    required this.x,
    required this.y,
  }) : currentShape = List.from(baseShape);

  List<Offset> getBlocks() {
    return currentShape;
  }

  void rotate() {
    currentShape = currentShape.map((b) => Offset(-b.dy, b.dx)).toList();
  }

  void resetRotation() {
    currentShape = List.from(baseShape);
  }
}

class BoardPainter extends CustomPainter {
  final List<List<Color?>> board;
  final Tetromino? currentPiece;
  final double blockSize;

  BoardPainter(this.board, this.currentPiece, this.blockSize);

  @override
  void paint(Canvas canvas, Size size) {
    // Draw background
    final paint = Paint()..color = Colors.black26;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Draw grid
    final gridPaint = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (int i = 0; i <= board.length; i++) {
      canvas.drawLine(
        Offset(0, i * blockSize),
        Offset(size.width, i * blockSize),
        gridPaint,
      );
    }
    for (int i = 0; i <= board[0].length; i++) {
      canvas.drawLine(
        Offset(i * blockSize, 0),
        Offset(i * blockSize, size.height),
        gridPaint,
      );
    }

    // Draw locked pieces
    for (int row = 0; row < board.length; row++) {
      for (int col = 0; col < board[row].length; col++) {
        if (board[row][col] != null) {
          _drawBlock(canvas, col, row, board[row][col]!);
        }
      }
    }

    // Draw current piece
    if (currentPiece != null) {
      for (Offset block in currentPiece!.getBlocks()) {
        int x = currentPiece!.x + block.dx.toInt();
        int y = currentPiece!.y + block.dy.toInt();
        if (y >= 0) {
          _drawBlock(canvas, x, y, currentPiece!.color);
        }
      }

      // Draw ghost piece
      int ghostY = currentPiece!.y;
      while (true) {
        currentPiece!.y++;
        if (_checkCollisionForGhost()) {
          currentPiece!.y--;
          break;
        }
        ghostY = currentPiece!.y;
      }
      currentPiece!.y = ghostY;
      
      for (Offset block in currentPiece!.getBlocks()) {
        int x = currentPiece!.x + block.dx.toInt();
        int y = currentPiece!.y + block.dy.toInt();
        if (y >= 0) {
          _drawGhostBlock(canvas, x, y, currentPiece!.color);
        }
      }
      currentPiece!.y = currentPiece!.y; // Reset handled
    }
  }

  bool _checkCollisionForGhost() {
    List<Offset> blocks = currentPiece!.getBlocks();
    for (Offset block in blocks) {
      int newX = currentPiece!.x + block.dx.toInt();
      int newY = currentPiece!.y + block.dy.toInt();
      if (newY >= board.length) return true;
      if (newY >= 0 && board[newY][newX] != null) return true;
    }
    return false;
  }

  void _drawBlock(Canvas canvas, int x, int y, Color color) {
    final paint = Paint()..color = color;
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRect(
      Rect.fromLTWH(x * blockSize + 1, y * blockSize + 1, blockSize - 2, blockSize - 2),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(x * blockSize + 1, y * blockSize + 1, blockSize - 2, blockSize - 2),
      borderPaint,
    );
  }

  void _drawGhostBlock(Canvas canvas, int x, int y, Color color) {
    final paint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRect(
      Rect.fromLTWH(x * blockSize + 1, y * blockSize + 1, blockSize - 2, blockSize - 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant BoardPainter oldDelegate) => true;
}

class NextPiecePainter extends CustomPainter {
  final Tetromino? piece;
  final double blockSize;

  NextPiecePainter(this.piece, this.blockSize);

  @override
  void paint(Canvas canvas, Size size) {
    if (piece == null) return;

    List<Offset> blocks = piece!.getBlocks();
    
    // Center the piece
    double minX = blocks.map((b) => b.dx).reduce(min);
    double maxX = blocks.map((b) => b.dx).reduce(max);
    double minY = blocks.map((b) => b.dy).reduce(min);
    double maxY = blocks.map((b) => b.dy).reduce(max);
    
    double pieceWidth = (maxX - minX + 1) * blockSize;
    double pieceHeight = (maxY - minY + 1) * blockSize;
    
    double offsetX = (size.width - pieceWidth) / 2 - minX * blockSize;
    double offsetY = (size.height - pieceHeight) / 2 - minY * blockSize;

    for (Offset block in blocks) {
      final paint = Paint()..color = piece!.color;
      canvas.drawRect(
        Rect.fromLTWH(
          offsetX + block.dx * blockSize,
          offsetY + block.dy * blockSize,
          blockSize - 2,
          blockSize - 2,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant NextPiecePainter oldDelegate) => true;
}
