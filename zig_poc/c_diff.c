#include <stdint.h>
#include <stddef.h>

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
