
// most of this is cribbed from sokol's sgl-microui-sapp.c

#if defined(_MSC_VER)
#    define _CRT_SECURE_NO_WARNINGS (1)
#endif
#include "sokol_gfx.h"
#include "sokol_app.h"
#include "sokol_gl.h"
#include "microui.h"
#include "atlas.inl"
#include <string.h>
#include <stdlib.h>

typedef struct {
    float r, g, b;
} color_t;

static struct {
    mu_Context mu_ctx;
    char logbuf[64000];
    int logbuf_updated;
    color_t bg;
} state = {
    .bg = { 90.0f, 95.0f, 100.0f }
};

/* UI functions */
static void test_window(mu_Context* ctx);
static void log_window(mu_Context* ctx);
static void style_window(mu_Context* ctx);

/* microui renderer functions (implementation is at the end of this file) */
static void r_init(sgl_pipeline);
static void r_begin(int disp_width, int disp_height);
static void r_end(void);
static void r_draw(void);
static void r_push_quad(mu_Rect dst, mu_Rect src, mu_Color color);
static void r_draw_rect(mu_Rect rect, mu_Color color);
static void r_draw_text(const char* text, mu_Vec2 pos, mu_Color color);
static void r_draw_icon(int id, mu_Rect rect, mu_Color color);
static int r_get_text_width(const char* text, int len);
static int r_get_text_height(void);
static void r_set_clip_rect(mu_Rect rect);

/* callbacks */
static int text_width_cb(mu_Font font, const char* text, int len) {
    (void)font;
    if (len == -1) {
        len = (int) strlen(text);
    }
    return r_get_text_width(text, len);
}

static int text_height_cb(mu_Font font) {
    (void)font;
    return r_get_text_height();
}

static void write_log(const char* text) {
    /* FIXME: THIS IS UNSAFE! */
    if (state.logbuf[0]) {
        strcat(state.logbuf, "\n");
    }
    strcat(state.logbuf, text);
    state.logbuf_updated = 1;
}

mu_Context* microui_init(void* p) {
    sgl_pipeline* ptr = (sgl_pipeline*) p;
    r_init(*ptr);
    mu_init(&state.mu_ctx);
    state.mu_ctx.text_width = text_width_cb;
    state.mu_ctx.text_height = text_height_cb;
    return &state.mu_ctx;
}

void microui_begin() {
    mu_begin(&state.mu_ctx);
}

void microui_end() {
    mu_end(&state.mu_ctx);
}

void microui_render(int w, int h) {
    r_begin(w, h);
    mu_Command* cmd = 0;
    while(mu_next_command(&state.mu_ctx, &cmd)) {
        switch (cmd->type) {
            case MU_COMMAND_TEXT: r_draw_text(cmd->text.str, cmd->text.pos, cmd->text.color); break;
            case MU_COMMAND_RECT: r_draw_rect(cmd->rect.rect, cmd->rect.color); break;
            case MU_COMMAND_ICON: r_draw_icon(cmd->icon.id, cmd->icon.rect, cmd->icon.color); break;
            case MU_COMMAND_CLIP: r_set_clip_rect(cmd->clip.rect); break;
        }
    }
    r_end();
}

void microui_draw_pass() {
    r_draw();
}


static const char key_map[512] = {
    [SAPP_KEYCODE_LEFT_SHIFT]       = MU_KEY_SHIFT,
    [SAPP_KEYCODE_RIGHT_SHIFT]      = MU_KEY_SHIFT,
    [SAPP_KEYCODE_LEFT_CONTROL]     = MU_KEY_CTRL,
    [SAPP_KEYCODE_RIGHT_CONTROL]    = MU_KEY_CTRL,
    [SAPP_KEYCODE_LEFT_ALT]         = MU_KEY_ALT,
    [SAPP_KEYCODE_RIGHT_ALT]        = MU_KEY_ALT,
    [SAPP_KEYCODE_ENTER]            = MU_KEY_RETURN,
    [SAPP_KEYCODE_BACKSPACE]        = MU_KEY_BACKSPACE,
};

static void event(const sapp_event* ev) {
    /* FIXME: need to filter out events consumed by the Dear ImGui debug UI */
    //__cdbgui_event(ev);
    switch (ev->type) {
        case SAPP_EVENTTYPE_MOUSE_DOWN:
            mu_input_mousedown(&state.mu_ctx, (int)ev->mouse_x, (int)ev->mouse_y, (1<<ev->mouse_button));
            break;
        case SAPP_EVENTTYPE_MOUSE_UP:
            mu_input_mouseup(&state.mu_ctx, (int)ev->mouse_x, (int)ev->mouse_y, (1<<ev->mouse_button));
            break;
        case SAPP_EVENTTYPE_MOUSE_MOVE:
            mu_input_mousemove(&state.mu_ctx, (int)ev->mouse_x, (int)ev->mouse_y);
            break;
        case SAPP_EVENTTYPE_MOUSE_SCROLL:
            //mu_input_mousewheel(&state.mu_ctx, (int)ev->scroll_y);
            break;
        case SAPP_EVENTTYPE_KEY_DOWN:
            mu_input_keydown(&state.mu_ctx, key_map[ev->key_code & 511]);
            break;
        case SAPP_EVENTTYPE_KEY_UP:
            mu_input_keyup(&state.mu_ctx, key_map[ev->key_code & 511]);
            break;
        case SAPP_EVENTTYPE_CHAR:
            {
                char txt[2] = { (char)(ev->char_code & 255), 0 };
                mu_input_text(&state.mu_ctx, txt);
            }
            break;
        default:
            break;
    }
}


/*== micrui renderer =========================================================*/
static sg_image atlas_img;
static sgl_pipeline pip;

static void r_init(sgl_pipeline p) {

    /* atlas image data is in atlas.inl file, this only contains alpha
       values, need to expand this to RGBA8
    */
    uint32_t rgba8_size = ATLAS_WIDTH * ATLAS_HEIGHT * 4;
    uint32_t* rgba8_pixels = (uint32_t*) malloc(rgba8_size);
    for (int y = 0; y < ATLAS_HEIGHT; y++) {
        for (int x = 0; x < ATLAS_WIDTH; x++) {
            int index = y*ATLAS_WIDTH + x;
            rgba8_pixels[index] = 0x00FFFFFF | ((uint32_t)atlas_texture[index]<<24);
        }
    }
    atlas_img = sg_make_image(&(sg_image_desc){
        .width = ATLAS_WIDTH,
        .height = ATLAS_HEIGHT,
        /* LINEAR would be better for text quality in HighDPI, but the
           atlas texture is "leaking" from neighbouring pixels unfortunately
        */
        .min_filter = SG_FILTER_NEAREST,
        .mag_filter = SG_FILTER_NEAREST,
        .data = {
            .subimage[0][0] = {
                .ptr = rgba8_pixels,
                .size = rgba8_size
            }
        }
    });

    pip = p;

/*    
    pip = sgl_make_pipeline(&(sg_pipeline_desc){
        .colors[0].blend = {
            .enabled = true,
            .src_factor_rgb = SG_BLENDFACTOR_SRC_ALPHA,
            .dst_factor_rgb = SG_BLENDFACTOR_ONE_MINUS_SRC_ALPHA
        }
    });
*/
    free(rgba8_pixels);
}

static void r_begin(int disp_width, int disp_height) {
    sgl_defaults();
    sgl_push_pipeline();
    sgl_load_pipeline(pip);
    sgl_enable_texture();
    sgl_texture(atlas_img);
    sgl_matrix_mode_projection();
    sgl_push_matrix();
    sgl_ortho(0.0f, (float) disp_width, (float) disp_height, 0.0f, -1.0f, +1.0f);
    sgl_begin_quads();
}

static void r_end(void) {
    sgl_end();
    sgl_pop_matrix();
    sgl_pop_pipeline();
}

static void r_draw(void) {
    sgl_draw();
}

static void r_push_quad(mu_Rect dst, mu_Rect src, mu_Color color) {
    float u0 = (float) src.x / (float) ATLAS_WIDTH;
    float v0 = (float) src.y / (float) ATLAS_HEIGHT;
    float u1 = (float) (src.x + src.w) / (float) ATLAS_WIDTH;
    float v1 = (float) (src.y + src.h) / (float) ATLAS_HEIGHT;

    float x0 = (float) dst.x;
    float y0 = (float) dst.y;
    float x1 = (float) (dst.x + dst.w);
    float y1 = (float) (dst.y + dst.h);

    sgl_c4b(color.r, color.g, color.b, color.a);
    sgl_v2f_t2f(x0, y0, u0, v0);
    sgl_v2f_t2f(x1, y0, u1, v0);
    sgl_v2f_t2f(x1, y1, u1, v1);
    sgl_v2f_t2f(x0, y1, u0, v1);
}

static void r_draw_rect(mu_Rect rect, mu_Color color) {
    r_push_quad(rect, atlas[ATLAS_WHITE], color);
}

static void r_draw_text(const char* text, mu_Vec2 pos, mu_Color color) {
    mu_Rect dst = { pos.x, pos.y, 0, 0 };
    for (const char* p = text; *p; p++) {
        mu_Rect src = atlas[ATLAS_FONT + (unsigned char)*p];
        dst.w = src.w;
        dst.h = src.h;
        r_push_quad(dst, src, color);
        dst.x += dst.w;
    }
}

static void r_draw_icon(int id, mu_Rect rect, mu_Color color) {
    mu_Rect src = atlas[id];
    int x = rect.x + (rect.w - src.w) / 2;
    int y = rect.y + (rect.h - src.h) / 2;
    r_push_quad(mu_rect(x, y, src.w, src.h), src, color);
}

static int r_get_text_width(const char* text, int len) {
    int res = 0;
    for (const char* p = text; *p && len--; p++) {
        res += atlas[ATLAS_FONT + (unsigned char)*p].w;
    }
    return res;
}

static int r_get_text_height(void) {
    return 18;
}

static void r_set_clip_rect(mu_Rect rect) {
    sgl_end();
    sgl_scissor_rect(rect.x, rect.y, rect.w, rect.h, true);
    sgl_begin_quads();
}



