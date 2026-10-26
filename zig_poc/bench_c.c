#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    char ch[4];      
    uint32_t attr;   
} Cell;

size_t diff_cells_c(const Cell* old_cells, const Cell* new_cells, size_t count) {
    size_t diffs = 0;
    for (size_t i = 0; i < count; i++) {
        if (old_cells[i].attr != new_cells[i].attr ||
            old_cells[i].ch[0] != new_cells[i].ch[0] ||
            old_cells[i].ch[1] != new_cells[i].ch[1] ||
            old_cells[i].ch[2] != new_cells[i].ch[2] ||
            old_cells[i].ch[3] != new_cells[i].ch[3]) {
            diffs++;
        }
    }
    return diffs;
}

int main() {
    size_t count = 10000000;
    Cell* old_cells = malloc(count * sizeof(Cell));
    Cell* new_cells = malloc(count * sizeof(Cell));
    
    for (size_t i = 0; i < count; i++) {
        old_cells[i].ch[0] = 'A';
        old_cells[i].ch[1] = 0;
        old_cells[i].ch[2] = 0;
        old_cells[i].ch[3] = 0;
        old_cells[i].attr = i % 256;
    }
    memcpy(new_cells, old_cells, count * sizeof(Cell));
    
    for (size_t i = 0; i < count; i += 7) {
        new_cells[i].attr = 999;
    }
    
    size_t sum = 0;
    for (int j = 0; j < 100; j++) {
        sum += diff_cells_c(old_cells, new_cells, count);
    }
    
    printf("%zu\n", sum);
    free(old_cells);
    free(new_cells);
    return 0;
}
