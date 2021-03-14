/* CastXML only takes one header-file as an argument so if your library needs
 * multiple header-files that aren't automatically included by your library
 * then you should create a header file to deal with it.                    */

// castxml --castxml-output=1,0,0 -I/nix/store/wsnw58h9pgjiihwz22vzj97mzkxrcfrx-libxml2-2.9.10-dev/include/libxml2/ -I/nix/store/x1h3zxbr0bif0xr2l44x2pl5hnnc2n0j-glibc-2.32-35-dev/include libxml2.h

#include <libxml/c14n.h>
#include <libxml/catalog.h>
#include <libxml/chvalid.h>
#include <libxml/debugXML.h>
#include <libxml/dict.h>
#include <libxml/encoding.h>
#include <libxml/entities.h>
#include <libxml/globals.h>
#include <libxml/hash.h>
#include <libxml/HTMLparser.h>
#include <libxml/HTMLtree.h>
#include <libxml/list.h>
#include <libxml/nanoftp.h>
#include <libxml/nanohttp.h>
#include <libxml/parser.h>
#include <libxml/parserInternals.h>
#include <libxml/pattern.h>
#include <libxml/relaxng.h>
#include <libxml/SAX2.h>
#include <libxml/SAX.h>
#include <libxml/schemasInternals.h>
#include <libxml/schematron.h>
#include <libxml/threads.h>
#include <libxml/tree.h>
#include <libxml/uri.h>
#include <libxml/valid.h>
#include <libxml/xinclude.h>
#include <libxml/xlink.h>
#include <libxml/xmlautomata.h>
#include <libxml/xmlerror.h>
#include <libxml/xmlexports.h>
#include <libxml/xmlIO.h>
#include <libxml/xmlmemory.h>
#include <libxml/xmlmodule.h>
#include <libxml/xmlreader.h>
#include <libxml/xmlregexp.h>
#include <libxml/xmlsave.h>
#include <libxml/xmlschemas.h>
#include <libxml/xmlschemastypes.h>
#include <libxml/xmlstring.h>
#include <libxml/xmlunicode.h>
#include <libxml/xmlversion.h>
#include <libxml/xmlwriter.h>
#include <libxml/xpath.h>
#include <libxml/xpathInternals.h>
#include <libxml/xpointer.h>

