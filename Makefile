prefix := /usr/local
bindir = $(prefix)/bin
srcdir := $(dir $(lastword $(MAKEFILE_LIST)))
CITO_HOST = cpp
CXXFLAGS = -Wall -O2
DOTNET_BASE_DIR := $(shell dotnet --info 2>/dev/null | sed -n 's/ Base Path:   //p')
ifdef DOTNET_BASE_DIR
DOTNET_REF_DIR := $(shell realpath '$(DOTNET_BASE_DIR)../../packs/Microsoft.NETCore.App.Ref'/*/ref/net* | head -1)
CSC := dotnet '$(DOTNET_BASE_DIR)Roslyn/bincore/csc.dll' -nologo $(patsubst %,'-r:$(DOTNET_REF_DIR)/System.%.dll', Collections Collections.Specialized Console Linq Runtime Text.RegularExpressions Threading)
endif
TEST_CFLAGS = -Wall -Werror
TEST_CXXFLAGS = -std=c++20 -Wall -Werror
SWIFTC = swiftc
ifeq ($(OS),Windows_NT)
JAVACPSEP = ;
SWIFTC += -no-color-diagnostics -sdk '$(SDKROOT)' -Xlinker -noexp -Xlinker -noimplib
else
JAVACPSEP = :
TEST_CFLAGS += -fsanitize=address -g
TEST_CXXFLAGS += -fsanitize=address -g
SWIFTC += -sanitize=address
endif
DC = dmd
PYTHON = python3 -B
INSTALL = install

MAKEFLAGS = -r
ifdef V
DO =
else
DO = @echo $@ &&
endif
DO_SUMMARY = $(DO)perl test/summary.pl $(filter %.txt, $^)
DO_CITO = $(DO)mkdir -p $(@D) && ($(CITO) -o $@ $< || grep '//FAIL:.*\<$(subst .,,$(suffix $@))\>' $<)
SOURCE_CI = Lexer.fu AST.fu Parser.fu ConsoleHost.fu Sema.fu GenBase.fu GenTyped.fu GenCCppD.fu GenCCpp.fu GenC.fu GenCl.fu GenCpp.fu GenCs.fu GenD.fu GenJava.fu GenJs.fu GenTs.fu GenPySwift.fu GenSwift.fu GenPy.fu

all: cito Transpiled.cpp Transpiled.cs Transpiled.js

ifeq ($(CITO_HOST),cpp)

CITO = ./cito

ifeq ($(OS),Windows_NT)

cito: cito.exe

cito.exe: cito.cpp Transpiled.cpp
	$(DO)$(CXX) -o $@ -std=c++20 $(CXXFLAGS) -s -static $^

else

cito: cito.cpp Transpiled.cpp
	$(DO)$(CXX) -o $@ -std=c++20 $(CXXFLAGS) $^

endif

else ifeq ($(CITO_HOST),cs)

CITO = dotnet run --no-build --

cito: bin/Debug/net6.0/cito.dll

bin/Debug/net6.0/cito.dll: $(addprefix $(srcdir),AssemblyInfo.cs Transpiled.cs CiTo.cs)
	dotnet build

else ifeq ($(CITO_HOST),node)

CITO = node cito.js

cito: Transpiled.js

else
$(error CITO_HOST must be "cpp", "cs" or "node")
endif

Transpiled.cpp Transpiled.js: $(SOURCE_CI)
	$(DO)$(CITO) -o $@ $^

Transpiled.cs: $(SOURCE_CI)
	$(DO)$(CITO) -o $@ -n Foxoft.Ci $^

test: test-c test-cpp test-cs test-d test-java test-js test-ts test-py test-swift test-cl test-error
	$(DO)perl test/summary.pl test/bin/*/*.txt

test-c test-GenC.fu: $(patsubst test/%.fu, test/bin/%/c.txt, $(wildcard test/*.fu))
	$(DO_SUMMARY)

test-cpp test-GenCpp.fu: $(patsubst test/%.fu, test/bin/%/cpp.txt, $(wildcard test/*.fu)) Transpiled.cpp
	$(DO_SUMMARY)

test-cs test-GenCs.fu: $(patsubst test/%.fu, test/bin/%/cs.txt, $(wildcard test/*.fu)) Transpiled.cs
	$(DO_SUMMARY)

test-d test-GenD.fu: $(patsubst test/%.fu, test/bin/%/d.txt, $(wildcard test/*.fu))
	$(DO_SUMMARY)

test-java test-GenJava.fu: $(patsubst test/%.fu, test/bin/%/java.txt, $(wildcard test/*.fu))
	$(DO_SUMMARY)

test-js test-GenJs.fu: $(patsubst test/%.fu, test/bin/%/js.txt, $(wildcard test/*.fu)) Transpiled.js
	$(DO_SUMMARY)

test-ts test-GenTs.fu: $(patsubst test/%.fu, test/bin/%/ts.txt, $(wildcard test/*.fu))
	$(DO_SUMMARY)

test-py test-GenPy.fu: $(patsubst test/%.fu, test/bin/%/py.txt, $(wildcard test/*.fu))
	$(DO_SUMMARY)

test-swift test-GenSwift.fu: $(patsubst test/%.fu, test/bin/%/swift.txt, $(wildcard test/*.fu))
	$(DO_SUMMARY)

test-cl test-GenCl.fu: $(patsubst test/%.fu, test/bin/%/cl.txt, $(wildcard test/*.fu))
	$(DO_SUMMARY)

test-GenCCpp.fu: test-c test-cpp

test-GenCCppD.fu: test-c test-cpp test-d

test-GenPySwift.fu: test-py test-swift

test-error test-Lexer.fu test-Parser.fu test-Sema.fu: $(patsubst test/error/%.fu, test/bin/%/error.txt, $(wildcard test/error/*.fu))
	$(DO_SUMMARY)

test-%.fu: $(addsuffix .txt, $(addprefix test/bin/%/, c cpp cs d java js ts py swift cl))
	#

test/bin/%/c.txt: test/bin/%/c.exe
	$(DO)./$< >$@ || grep '//FAIL:.*\<c\>' test/$*.fu

test/bin/%/cpp.txt: test/bin/%/cpp.exe
	$(DO)./$< >$@ || grep '//FAIL:.*\<cpp\>' test/$*.fu

test/bin/%/cs.txt: test/bin/%/cs.dll test/cs.runtimeconfig.json
	$(DO)dotnet exec --runtimeconfig test/cs.runtimeconfig.json $< >$@ || grep '//FAIL:.*\<cs\>' test/$*.fu

test/bin/%/d.txt: test/bin/%/d.exe
	$(DO)./$< >$@ || grep '//FAIL:.*\<d\>' test/$*.fu

test/bin/%/java.txt: test/bin/%/Test.class test/bin/Runner.class
	$(DO)java -cp "test/bin$(JAVACPSEP)$(<D)" Runner >$@ || grep '//FAIL:.*\<java\>' test/$*.fu

test/bin/%/js.txt: test/bin/%/Test.js test/bin/%/Runner.js
	$(DO)(cd $(@D) && node Runner.js >$(@F)) || grep '//FAIL:.*\<js\>' test/$*.fu

test/bin/%/ts.txt: test/bin/%/Test.ts test/node_modules test/tsconfig.json
	$(DO)test/node_modules/.bin/ts-node $< >$@ || grep '//FAIL:.*\<ts\>' test/$*.fu

test/bin/%/py.txt: test/Runner.py test/bin/%/Test.py
	$(DO)PYTHONPATH=$(@D) $(PYTHON) $< >$@ || grep '//FAIL:.*\<py\>' test/$*.fu

test/bin/%/swift.txt: test/bin/%/swift.exe
	$(DO)./$< >$@ || grep '//FAIL:.*\<swift\>' test/$*.fu

test/bin/%/cl.txt: test/bin/%/cl.exe
	$(DO)./$< >$@ || grep '//FAIL:.*\<cl\>' test/$*.fu

test/bin/%/c.exe: test/bin/%/Test.c test/Runner.c
	$(DO)$(CC) -o $@ $(TEST_CFLAGS) -Wno-unused-function -I $(<D) $^ `pkg-config --cflags --libs glib-2.0` -lm || grep '//FAIL:.*\<c\>' test/$*.fu

test/bin/%/cpp.exe: test/bin/%/Test.cpp test/Runner.cpp
	$(DO)$(CXX) -o $@ $(TEST_CXXFLAGS) -I $(<D) $^ || grep '//FAIL:.*\<cpp\>' test/$*.fu

test/bin/%/cs.dll: test/bin/%/Test.cs test/Runner.cs
	$(DO)$(CSC) -out:$@ $^ || grep '//FAIL:.*\<cs\>' test/$*.fu

test/bin/%/d.exe: test/bin/%/Test.d test/Runner.d
	$(DO)$(DC) -of$@ $(DFLAGS) -I$(<D) $^ || grep '//FAIL:.*\<d\>' test/$*.fu

test/bin/%/Test.class: test/bin/%/Test.java
	$(DO)javac -d $(@D) -encoding utf8 $(<D)/*.java || grep '//FAIL:.*\<java\>' test/$*.fu

test/bin/%/Runner.js: test/Runner.js
	$(DO)mkdir -p $(@D) && cp $< $@

test/bin/%/swift.exe: test/bin/%/Test.swift test/main.swift
	$(DO)$(SWIFTC) -o $@ $^ || grep '//FAIL:.*\<swift\>' test/$*.fu

test/bin/%/cl.exe: test/bin/%/cl.o test/Runner-cl.cpp
	$(DO)clang++ -o $@ $(TEST_CFLAGS) $^ || grep '//FAIL:.*\<cl\>' test/$*.fu

test/bin/%/cl.o: test/bin/%/Test.cl
	$(DO)clang -c -o $@ $(TEST_CFLAGS) -Wno-constant-logical-operand -cl-std=CL2.0 -include opencl-c.h $< || grep '//FAIL:.*\<cl\>' test/$*.fu

test/bin/%/Test.c: test/%.fu cito
	$(DO_CITO)

test/bin/%/Test.cpp: test/%.fu cito
	$(DO_CITO)

test/bin/%/Test.cs: test/%.fu cito
	$(DO_CITO)

test/bin/%/Test.d: test/%.fu cito
	$(DO_CITO)

test/bin/%/Test.java: test/%.fu cito
	$(DO_CITO)

test/bin/%/Test.js: test/%.fu cito
	$(DO_CITO)

test/bin/%/Test.ts: test/%.fu cito test/Runner.ts
	$(DO)mkdir -p $(@D) && ($(CITO) -D TS -o $@ $< && cat test/Runner.ts >>$@ || grep '//FAIL:.*\<ts\>' $<)

test/bin/%/Test.py: test/%.fu cito
	$(DO_CITO)

test/bin/%/Test.swift: test/%.fu cito
	$(DO_CITO)

test/bin/%/Test.cl: test/%.fu cito
	$(DO_CITO)

test/bin/Resource/java.txt: test/bin/Resource/Test.class test/bin/Runner.class
	$(DO)java -cp "test/bin$(JAVACPSEP)$(<D)$(JAVACPSEP)test" Runner >$@

$(addprefix test/bin/Resource/Test., c cpp cs d java js ts py swift cl): test/Resource.fu cito
	$(DO)mkdir -p $(@D) && ($(CITO) -o $@ -I $(<D) $< || grep '//FAIL:.*\<$(subst .,,$(suffix $@))\>' $<)

.PRECIOUS: test/bin/%/Test.c test/bin/%/Test.cpp test/bin/%/Test.cs test/bin/%/Test.d test/bin/%/Test.java test/bin/%/Test.js test/bin/%/Test.ts test/bin/%/Test.d.ts test/bin/%/Test.py test/bin/%/Test.swift test/bin/%/Test.cl

test/bin/Runner.class: test/Runner.java test/bin/Basic/Test.class
	$(DO)javac -d $(@D) -cp test/bin/Basic $<

test/node_modules: test/package.json
	cd $(<D) && npm i --no-package-lock

test/bin/%/error.txt: test/error/%.fu cito
	$(DO)mkdir -p $(@D) && ! $(CITO) -o $(@:%.txt=%.cs) $< 2>$@ && perl -ne 'print "$$ARGV($$.): $$1\n" while m!//(ERROR: .+?)(?=$$| //)!g' $< | diff -u --strip-trailing-cr - $@ && echo PASSED >$@

test-transpile: $(patsubst test/%.fu, test/$(CITO_HOST)/%/all, $(wildcard test/*.fu)) test/$(CITO_HOST)/CiTo/all

test/$(CITO_HOST)/%/all: test/%.fu cito
	$(DO)mkdir -p $(@D) && $(CITO) -o $(@D)/Test.c,cpp,cs,d,java,js,d.ts,ts,py,swift,cl $< || true

test/$(CITO_HOST)/CiTo/all: $(SOURCE_CI) cito
	$(DO)mkdir -p $(@D) && $(CITO) -o $(@D)/Test.cpp,cs,d,js,d.ts,ts $(SOURCE_CI)

test/$(CITO_HOST)/Resource/all: test/Resource.fu cito
	$(DO)mkdir -p $(@D) && $(CITO) -o $(@D)/Test.c,cpp,cs,d,java,js,d.ts,ts,py,swift,cl -I $(<D) $<

coverage/output.xml:
	dotnet-coverage collect -f xml -o $@ "make -j`nproc` test-transpile test-error CITO_HOST=cs"

coverage: coverage/output.xml
	reportgenerator -reports:$< -targetdir:coverage

codecov: coverage/output.xml
	./codecov -f $<

host-diff:
	$(MAKE) test-transpile CITO_HOST=cpp
	$(MAKE) test-transpile CITO_HOST=cs
	$(MAKE) test-transpile CITO_HOST=node
	diff -ruI "[0-9][Ee][-+][0-9]\|\.0" test/cpp test/cs
	diff -ruI "[0-9][Ee][-+][0-9]" test/cs test/node

install: cito
	$(INSTALL) -D $< $(DESTDIR)$(bindir)/cito

uninstall:
	$(RM) $(DESTDIR)$(bindir)/cito

clean:
	$(RM) cito cito.exe
	$(RM) -r test/bin test/cpp test/cs test/node

.PHONY: all test test-c test-cpp test-cs test-d test-java test-js test-ts test-py test-swift test-cl test-error test-transpile coverage/output.xml coverage codecov host-diff install uninstall clean

.DELETE_ON_ERROR:
