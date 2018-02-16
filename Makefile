VERILOGDIR=   $(DESTDIR)/usr/local/verilog
INSTALLDIR=   $(DESTDIR)/usr/local/bin
DOCUMENTROOT= $(DESTDIR)/www/pages

SCRIPTPATH=   py393
COCOTB =      cocotb

LINK = ln
OWN = -o root -g root
#INSTALL = $(INSTALL)
INSTMODE   = 0755
DOCMODE    = 0644
PYTHON_EXE = $(SCRIPTPATH)/*.py \
             cocotb/socket_command.py

FPGA_BITFILES =   *.bit
VERILOG_HEADERS = system_defines.vh \
                  includes/x393_parameters.vh \
				  includes/x393_localparams.vh \
				  includes/x393_cur_params_target.vh

COMMAND_FILES =   py393/hargs \
				  py393/hargs-auto \
				  py393/hargs-after \
				  py393/hargs-eyesis \
				  py393/hargs-hispi \
				  py393/hargs-post-par12 \
				  py393/hargs-power_par12 \
				  py393/hargs-power-eyesis \
				  py393/includes \
				  py393/startup5 \
				  py393/startup14

all:
	@echo "make all in x393"
install:
	@echo "make install in x393"
	$(INSTALL) $(OWN) -d $(VERILOGDIR)
	$(INSTALL) $(OWN) -d $(DOCUMENTROOT)
	$(INSTALL) $(OWN) -d $(INSTALLDIR)

	$(INSTALL) $(OWN) -m $(INSTMODE) $(PYTHON_EXE)                          $(INSTALLDIR)

	$(INSTALL) $(OWN) -m $(DOCMODE) $(FPGA_BITFILES)                        $(VERILOGDIR)
	$(INSTALL) $(OWN) -m $(DOCMODE) $(VERILOG_HEADERS)                      $(VERILOGDIR)
	$(INSTALL) $(OWN) -m $(DOCMODE) $(COMMAND_FILES)                        $(VERILOGDIR)

	$(LINK) -s -r        $(INSTALLDIR)/imgsrv.py                            $(DOCUMENTROOT)
#	$(INSTALL) $(OWN) -m $(INSTMODE) $(SCRIPTPATH)/imgsrv.py                $(DOCUMENTROOT)
#unistall
#    rm $(SCRIPTPATH)/imgsrv.py

clean:
	@echo "make clean in x393"
