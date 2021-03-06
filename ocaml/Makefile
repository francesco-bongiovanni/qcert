#
# Copyright 2015-2016 IBM Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

include ../Makefile.coq_modules

## Configuraton
QCERT_HOME=$(CURDIR)/..

############# Shouldn't have to be changed after this
OCAMLBUILD= ocamlbuild \
		-no-links -classic-display \
		-tags annot -use-ocamlfind -package unix -package base64

MENHIRFLAG=-use-menhir
#MENHIRFLAG=

## Mains
MAIN=qcert
MAIN2=qdata
MAIN3=qcertJS

TARGET=native

## Toplevel
all: ../bin/$(MAIN) ../bin/$(MAIN2)

js: ../bin/$(MAIN3).js

## Extraction
VO_FILES = $(MODULES:%=../coq/%.vo)

extracted: extracted/StaticConfig.ml extracted/QcertCompiler.ml extracted/QcertCompiler.mli

extracted/StaticConfig.ml extracted/QcertCompiler.ml extracted/QcertCompiler.mli: $(VO_FILES)
	rm -rf extracted
	mkdir -p extracted
	echo "(* This file is generated *)" > extracted/StaticConfig.ml
	echo "let qcert_home = \"$(QCERT_HOME)\"" >> extracted/StaticConfig.ml
	(cd extracted; coqc -R ../../coq Qcert ../QcertExtraction.v)

## Native
../bin/$(MAIN): extracted $(MAIN).$(TARGET)
	cp _build/$(MAIN).$(TARGET) ../bin/$(MAIN)

$(MAIN).$(TARGET): extracted
	$(OCAMLBUILD) $(MENHIRFLAG) -Is extracted -Is src $(MAIN).$(TARGET)

../bin/$(MAIN2): extracted $(MAIN2).$(TARGET)
	cp _build/$(MAIN2).$(TARGET) ../bin/$(MAIN2)

$(MAIN2).$(TARGET): extracted
	$(OCAMLBUILD) $(MENHIRFLAG) -Is extracted -Is src $(MAIN2).$(TARGET)

## JavaScript
../bin/$(MAIN3).js: extracted _build_js/$(MAIN3).byte
	js_of_ocaml _build_js/$(MAIN3).byte
	cp _build_js/$(MAIN3).js ../bin/$(MAIN3).js

_build_js/$(MAIN3).byte: extracted $(MAIN3).ml
	$(OCAMLBUILD) $(MENHIRFLAG) -build-dir _build_js -use-ocamlfind -package js_of_ocaml -package js_of_ocaml.ppx -Is extracted -Is src $(MAIN3).byte

## Whisk
wsk-update: js
	wsk action update qcert _build_js/$(MAIN3).js

wsk-invoke:
	wsk action invoke -br qcert -p source lambda_nra -p target nraenv \
		-p query 'Persons.filter{ p => p.age = 32 }'

## Clean

clean:
	ocamlbuild -clean -no-log
	rm -rf _build
	rm -rf _build_js
	rm -f ../bin/$(MAIN) ../bin/$(MAIN2)
	rm -f ../bin/$(MAIN3).js

cleanall: clean
	rm -f RuleLexer.ml RuleParser.ml RuleParser.mli
	rm -f CampLexer.ml CampParser.ml CampParser.mli
	rm -f DataLexer.ml DataParser.ml DataParser.mli
	rm -f SexpLexer.ml SexpParser.ml SexpParser.mli
	rm -f QcertExtraction.glob QcertExtraction.vo .QcertExtraction.aux
	rm -rf extracted
	rm -rf *~

.NOTPARALLEL: 

