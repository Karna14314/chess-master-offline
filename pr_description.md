💡 **What:**
Replaced nested string interpolation loops (`'$file$rank'`) with a direct 0x88 index loop (`for (int i = 0; i < 128; i++) { if ((i & 0x88) == 0) ... }`) iterating over the `state.board.board` array in `GameNotifier.validateStartingPieceCount` and `validateAllPiecesPlaced`.

🎯 **Why:**
String concatenation inside tight loops (like those used for board validations checking 64 squares multiple times) introduces unnecessary allocations and overhead. Using the 1D 0x88 index array is the native representation of the `chess` library and is significantly faster since it avoids string allocations and map lookups.

📊 **Measured Improvement:**
A dedicated benchmark measuring piece counting via string interpolation vs. `0x88` iteration over 500,000 runs yielded:
* Baseline (String Loop): 3259 ms
* Optimized (0x88 Loop): 753 ms
* **Improvement:** ~76.89% faster.
