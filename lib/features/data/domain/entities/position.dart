class Position {
  final int x;
  final int y;

  const Position(this.x, this.y);

  Position translate(int dx, int dy) => Position(x + dx, y + dy);
}
