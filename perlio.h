#ifndef _PERLIO_H
#define _PERLIO_H
/*
  Interface for perl to IO functions.
  There is a hierachy of Configure determined #define controls:
   USE_STDIO   - forces PerlIO_xxx() to be #define-d onto stdio functions.
                 This is used for x2p subdirectory and for conservative
                 builds - "just like perl5.00X used to be".
                 This dominates over the others.

   USE_PERLIO  - The primary Configure variable that enables PerlIO.
                 If USE_PERLIO is _NOT_ set
                   then USE_STDIO above will be set to be conservative.
                 If USE_PERLIO is set
                   then there are two modes determined by USE_SFIO:

   USE_SFIO    - If set causes PerlIO_xxx() to be #define-d onto sfio functions.
                 A backward compatability mode for some specialist applications.

                 If USE_SFIO is not set then PerlIO_xxx() are real functions
                 defined in perlio.c which implement extra functionality
                 required for utf8 support.

   One further note - the table-of-functions scheme controlled
   by PERL_IMPLICIT_SYS turns on USE_PERLIO so that iperlsys.h can
   #define PerlIO_xxx() to go via the function table, without having
   to #undef them from (say) stdio forms.

*/

#if defined(PERL_IMPLICIT_SYS)
#ifndef USE_PERLIO
# define USE_PERLIO
#endif
#endif

#ifndef USE_PERLIO
# define USE_STDIO
#endif

#ifdef USE_STDIO
#  ifndef PERLIO_IS_STDIO
#      define PERLIO_IS_STDIO
#  endif
#endif

/* --------------------  End of Configure controls ---------------------------- */

/*
 * Although we may not want stdio to be used including <stdio.h> here
 * avoids issues where stdio.h has strange side effects
 */
#include <stdio.h>

#if defined(USE_64_BIT_STDIO) && defined(HAS_FTELLO) && !defined(USE_FTELL64)
#define ftell ftello
#endif

#if defined(USE_64_BIT_STDIO) && defined(HAS_FSEEKO) && !defined(USE_FSEEK64)
#define fseek fseeko
#endif

#ifdef PERLIO_IS_STDIO
/* #define PerlIO_xxxx() as equivalent stdio function */
#include "perlsdio.h"
#else  /* PERLIO_IS_STDIO */
#ifdef USE_SFIO
/* #define PerlIO_xxxx() as equivalent sfio function */
#include "perlsfio.h"
#endif /* USE_SFIO */
#endif /* PERLIO_IS_STDIO */

#ifndef PerlIO
/* ----------- PerlIO implementation ---------- */
/* PerlIO not #define-d to something else - define the implementation */

typedef struct _PerlIO PerlIOl;
typedef struct _PerlIO_funcs PerlIO_funcs;
typedef PerlIOl *PerlIO;
#define PerlIO PerlIO
#define PERLIO_LAYERS 1

extern void	PerlIO_define_layer	(PerlIO_funcs *tab);
extern SV *	PerlIO_find_layer	(const char *name, STRLEN len);
extern PerlIO *	PerlIO_push		(PerlIO *f,PerlIO_funcs *tab,const char *mode);
extern void	PerlIO_pop		(PerlIO *f);

#endif /* PerlIO */

/* ----------- End of implementation choices  ---------- */

#ifndef PERLIO_IS_STDIO
/* Not using stdio _directly_ as PerlIO */

/* We now need to determine  what happens if source trys to use stdio.
 * There are three cases based on PERLIO_NOT_STDIO which XS code
 * can set how it wants.
 */

#ifdef PERL_CORE
/* Make a choice for perl core code
   - currently this is set to try and catch lingering raw stdio calls.
     This is a known issue with some non UNIX ports which still use
     "native" stdio features.
*/
#ifndef PERLIO_NOT_STDIO
#define PERLIO_NOT_STDIO 1
#endif
#endif

#ifdef PERLIO_NOT_STDIO
#if PERLIO_NOT_STDIO
/*
 * PERLIO_NOT_STDIO #define'd as 1
 * Case 1: Strong denial of stdio - make all stdio calls (we can think of) errors
 */
#include "nostdio.h"
#else /* if PERLIO_NOT_STDIO */
/*
 * PERLIO_NOT_STDIO #define'd as 0
 * Case 2: Declares that both PerlIO and stdio can be used
 */
#endif /* if PERLIO_NOT_STDIO */
#else  /* ifdef PERLIO_NOT_STDIO */
/*
 * PERLIO_NOT_STDIO not defined
 * Case 3: Try and fake stdio calls as PerlIO calls
 */
#include "fakesdio.h"
#endif /* ifndef PERLIO_NOT_STDIO */
#endif /* PERLIO_IS_STDIO */

#define specialCopIO(sv) ((sv) != Nullsv)

/* ----------- fill in things that have not got #define'd  ---------- */

#ifndef Fpos_t
#define Fpos_t Off_t
#endif

#ifndef EOF
#define EOF (-1)
#endif

/* This is to catch case with no stdio */
#ifndef BUFSIZ
#define BUFSIZ 1024
#endif

#ifndef SEEK_SET
#define SEEK_SET 0
#endif

#ifndef SEEK_CUR
#define SEEK_CUR 1
#endif

#ifndef SEEK_END
#define SEEK_END 2
#endif

/* --------------------- Now prototypes for functions --------------- */

#ifndef NEXT30_NO_ATTRIBUTE
#ifndef HASATTRIBUTE       /* disable GNU-cc attribute checking? */
#ifdef  __attribute__      /* Avoid possible redefinition errors */
#undef  __attribute__
#endif
#define __attribute__(attr)
#endif
#endif

#ifndef PerlIO_init
extern void	PerlIO_init		(void);
#endif
#ifndef PerlIO_stdoutf
extern int	PerlIO_stdoutf		(const char *,...)
					__attribute__((__format__ (__printf__, 1, 2)));
#endif
#ifndef PerlIO_puts
extern int	PerlIO_puts		(PerlIO *,const char *);
#endif
#ifndef PerlIO_open
extern PerlIO *	PerlIO_open		(const char *,const char *);
#endif
#ifndef PerlIO_close
extern int	PerlIO_close		(PerlIO *);
#endif
#ifndef PerlIO_eof
extern int	PerlIO_eof		(PerlIO *);
#endif
#ifndef PerlIO_error
extern int	PerlIO_error		(PerlIO *);
#endif
#ifndef PerlIO_clearerr
extern void	PerlIO_clearerr		(PerlIO *);
#endif
#ifndef PerlIO_getc
extern int	PerlIO_getc		(PerlIO *);
#endif
#ifndef PerlIO_putc
extern int	PerlIO_putc		(PerlIO *,int);
#endif
#ifndef PerlIO_flush
extern int	PerlIO_flush		(PerlIO *);
#endif
#ifndef PerlIO_ungetc
extern int	PerlIO_ungetc		(PerlIO *,int);
#endif
#ifndef PerlIO_fileno
extern int	PerlIO_fileno		(PerlIO *);
#endif
#ifndef PerlIO_fdopen
extern PerlIO *	PerlIO_fdopen		(int, const char *);
#endif
#ifndef PerlIO_importFILE
extern PerlIO *	PerlIO_importFILE	(FILE *,int);
#endif
#ifndef PerlIO_exportFILE
extern FILE *	PerlIO_exportFILE	(PerlIO *,int);
#endif
#ifndef PerlIO_findFILE
extern FILE *	PerlIO_findFILE		(PerlIO *);
#endif
#ifndef PerlIO_releaseFILE
extern void	PerlIO_releaseFILE	(PerlIO *,FILE *);
#endif
#ifndef PerlIO_read
extern SSize_t	PerlIO_read		(PerlIO *,void *,Size_t);
#endif
#ifndef PerlIO_write
extern SSize_t	PerlIO_write		(PerlIO *,const void *,Size_t);
#endif
#ifndef PerlIO_setlinebuf
extern void	PerlIO_setlinebuf	(PerlIO *);
#endif
#ifndef PerlIO_printf
extern int	PerlIO_printf		(PerlIO *, const char *,...)
					__attribute__((__format__ (__printf__, 2, 3)));
#endif
#ifndef PerlIO_sprintf
extern int	PerlIO_sprintf		(char *, int, const char *,...)
					__attribute__((__format__ (__printf__, 3, 4)));
#endif
#ifndef PerlIO_vprintf
extern int	PerlIO_vprintf		(PerlIO *, const char *, va_list);
#endif
#ifndef PerlIO_tell
extern Off_t	PerlIO_tell		(PerlIO *);
#endif
#ifndef PerlIO_seek
extern int	PerlIO_seek		(PerlIO *, Off_t, int);
#endif
#ifndef PerlIO_rewind
extern void	PerlIO_rewind		(PerlIO *);
#endif
#ifndef PerlIO_has_base
extern int	PerlIO_has_base		(PerlIO *);
#endif
#ifndef PerlIO_has_cntptr
extern int	PerlIO_has_cntptr	(PerlIO *);
#endif
#ifndef PerlIO_fast_gets
extern int	PerlIO_fast_gets	(PerlIO *);
#endif
#ifndef PerlIO_canset_cnt
extern int	PerlIO_canset_cnt	(PerlIO *);
#endif
#ifndef PerlIO_get_ptr
extern STDCHAR * PerlIO_get_ptr		(PerlIO *);
#endif
#ifndef PerlIO_get_cnt
extern int	PerlIO_get_cnt		(PerlIO *);
#endif
#ifndef PerlIO_set_cnt
extern void	PerlIO_set_cnt		(PerlIO *,int);
#endif
#ifndef PerlIO_set_ptrcnt
extern void	PerlIO_set_ptrcnt	(PerlIO *,STDCHAR *,int);
#endif
#ifndef PerlIO_get_base
extern STDCHAR * PerlIO_get_base	(PerlIO *);
#endif
#ifndef PerlIO_get_bufsiz
extern int	PerlIO_get_bufsiz	(PerlIO *);
#endif
#ifndef PerlIO_tmpfile
extern PerlIO *	PerlIO_tmpfile		(void);
#endif
#ifndef PerlIO_stdin
extern PerlIO *	PerlIO_stdin		(void);
#endif
#ifndef PerlIO_stdout
extern PerlIO *	PerlIO_stdout		(void);
#endif
#ifndef PerlIO_stderr
extern PerlIO *	PerlIO_stderr		(void);
#endif
#ifndef PerlIO_getpos
extern int	PerlIO_getpos		(PerlIO *,Fpos_t *);
#endif
#ifndef PerlIO_setpos
extern int	PerlIO_setpos		(PerlIO *,const Fpos_t *);
#endif
#ifndef PerlIO_fdupopen
extern PerlIO *	PerlIO_fdupopen		(PerlIO *);
#endif
#ifndef PerlIO_isutf8
extern int	PerlIO_isutf8		(PerlIO *);
#endif
#ifndef PerlIO_apply_layers
extern int	PerlIO_apply_layers	(pTHX_ PerlIO *f, const char *mode, const char *names);
#endif
#ifndef PerlIO_binmode
extern int	PerlIO_binmode		(pTHX_ PerlIO *f, int iotype, int omode, const char *names);
#endif

extern void PerlIO_debug(const char *fmt,...);

#endif /* _PERLIO_H */
