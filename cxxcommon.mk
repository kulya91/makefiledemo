### ARC_TARGET - target name for archive file, excluding file extension.
### ARC_TARGET - 静态库
###
### SO_TARGET - target name for shared object file, excluding file extension.
### SO_TARGET -  动态库
### APP_TARGET - target name of application.
### APP_TARGET - 进程
###
### SRCS    源代码文件 一般是.c .cpp等 非头文件
###
### LIB_SUFFIX 其实就是在文件后面加一个字符串，一般没啥用
### 
### TOP 顶层目录
### 
### OBJDIR 临时库存放的目录，如果没有给出，就会在顶层目录下面创建一个build目录
###
### INC_PATH 所有头文件的目录
###
### LIB_PATH 如果是so 或者是APP，需要依赖的lib库目录
###
### LIBS    所有的依赖库
###
### INSTALL_LIB_PATH 静态库安装目录
###
### INSTALL_APP_PATH APP安装目录
###
### APP_DIR APP安装在INSTALL_APP_PATH目下的子目录 如果定义了INSTALL_APP_PATH，就会忽略APP_DIR
###
### CROSS 交叉编译时使用
###
### SUB_FILE 其他需要安装的文件列表
### 
### CP_FILE 需要拷贝的文件
###
### CPFILE_PATH 需要拷贝到指定的目录


## ARC_TARGET 静态库 后面加 .a
ifneq ($(ARC_TARGET),)
  ARC_TARGET := lib$(ARC_TARGET)$(LIB_SUFFIX).a
endif

## SO_TARGET shared库 后面加.so
ifneq ($(SO_TARGET),)
  SO_TARGET := lib$(SO_TARGET)$(LIB_SUFFIX).so
endif

## 如果木有存放临时库的地方，存放top目录下build
ifeq ($(OBJDIR),)
  OBJDIR :=$(TOP)/build/
endif

## C的源文件
CSRCS:=$(filter %.c %.C,$(SRCS))
## C++的源文件
CPPSRCS:=$(filter %.cc %.CC %.cpp %.Cpp %.CPP,$(SRCS))

## 去除目录，只剩文件名和后缀，此时只需要把后缀修改成.o然后再加上一个目录，就是OBJS了
SRCFILE:=$(notdir $(SRCS))

## 所有 .o文件存放路径
#OBJS:=$(patsubst %.c,%.o,$(SRCFILE))
OBJS :=$(SRCFILE:.c=.o)
OBJS :=$(OBJS:.C=.o)
OBJS :=$(OBJS:.cc=.o)
OBJS :=$(OBJS:.CC=.o)
OBJS :=$(OBJS:.cpp=.o)
OBJS :=$(OBJS:.Cpp=.o)
OBJS :=$(OBJS:.CPP=.o)
#OBJS :=$(addprefix $(OBJDIR),$(OBJS))
OBJS :=$(foreach file,$(SRCS),$(OBJDIR)$(basename $(notdir $(file))).o)

## 如果是 Debug模式 如下
ifeq ($(DEBUG),1)
  CFLAGS += -g
  CFLAGS += -O0
  CFLAGS += -DDEBUG=$(DEBUG)
endif

## Release
ifeq ($(DEBUG),0)
  CFLAGS += -O2
  CFLAGS += -DNDEBUG
endif

# 动态库 
ifneq ($(SO_TARGET),)
  CFLAGS += -fpic
endif

#科达的通讯库如osp必须要 _LINUX_,所以此处增加一个，木有坏处
CFLAGS += -D_LINUX_ 

#所有头文件 路径
CFLAGS += $(foreach dir,$(INC_PATH),-I$(dir))

#依赖的静态库路径
LDFLAGS += $(foreach lib,$(LIB_PATH),-L$(lib))

# 动态库 
ifneq ($(SO_TARGET),)
 LDFLAGS += -shared
endif

## 加入 rt库
LDFLAGS += -lrt

##链接的所有静态库
LDFLAGS += $(foreach lib,$(LIBS),-l$(lib)$(LIB_SUFFIX))

## 如果木有提供INSTALL_LIB_PATH 程序自动给出目录 
ifndef INSTALL_LIB_PATH
	INSTALL_LIB_PATH = $(TOP)/lib/
endif

## 默认应用程序安装路径
ifndef INSTALL_APP_PATH
    INSTALL_APP_PATH = $(TOP)/app
endif

CP      = $(CROSS)cp
CC      = $(CROSS)gcc
CPP     = $(CROSS)g++
LD      = $(CROSS)g++
AR      = $(CROSS)ar
INSTALL = install -D -m 644
OBJDUMP = objdump
RM      = -@rm -f

define NEWLINE


endef

## 去掉前后空格后ARC_TARGET还有值 
ifneq ($(strip $(ARC_TARGET)),)

##  CFLAGS += -DFD_SETSIZE=512

  all: $(ARC_TARGET) ARLINK ARCINSTALL

  install_arc: $(ARC_TARGET) ARLINK ARCINSTALL
#$(AR) crus $(ARC_TARGET) $(OBJS)
#$(INSTALL) $(ARC_TARGET) $(INSTALL_LIB_PATH)/$(ARC_TARGET)

  $(ARC_TARGET) : GENEOBJ 

  ARLINK:
	$(AR) crus $(ARC_TARGET) $(OBJS)
  ARCINSTALL:
	$(INSTALL) $(ARC_TARGET) $(INSTALL_LIB_PATH)/$(ARC_TARGET)

  uninstall: uninstallarc

  uninstallarc:
	$(foreach file, $(INSTALL_INC), $(RM) $(INSTALL_INC_PATH)/$(file) $(NEWLINE))
	$(RM) $(INSTALL_LIB_PATH)/$(ARC_TARGET)

  clean: cleanarc

  cleanarc:
	$(RM) $(ARC_TARGET) $(OBJS)

endif


ifneq ($(strip $(SO_TARGET)),)

  all: install

  install: install_inc install_so

  install_so: $(SO_TARGET)
	$(INSTALL) $(SO_TARGET) $(INSTALL_LIB_PATH)/$(SO_TARGET)
	$(foreach file, $(SUB_FILE), $(INSTALL) $(file) $(INSTALL_LIB_PATH)/$(file) $(NEWLINE))
	$(foreach file, $(CP_FILE), $(CP) -rf $(CPFILE_PATH)$(file) $(INSTALL_LIB_PATH)/$(file) $(NEWLINE))     
  $(SO_TARGET) : GENEOBJ
	$(LD) $(OBJS) -o $(SO_TARGET) $(LDFLAGS) -fpic

  uninstall: uninstallso

  uninstallso:
	$(foreach file, $(INSTALL_INC), $(RM) $(INSTALL_INC_PATH)/$(file) $(NEWLINE))
	$(RM) $(INSTALL_LIB_PATH)/$(ARC_TARGET)

  clean: cleanso

  cleanso:
	$(RM) $(SO_TARGET) $(CP_FILE) $(OBJS)
else
#echo $(SRCFILE)
#$(foreach file,$(OBJS), $(file))
endif


## Rules for making applications
## 生成可执行文件

ifneq ($(strip $(APP_TARGET)),)

  all: install

  install: install_inc install_app

  install_app: $(APP_TARGET)
	$(INSTALL) $(APP_TARGET) $(INSTALL_APP_PATH)/$(APP_TARGET)

  $(APP_TARGET): GENEOBJ
	$(LD) $(OBJS) -o $(APP_TARGET) $(LDFLAGS)

  clean: cleanapp

  cleanapp:
	$(RM) $(APP_TARGET)

endif

GENEOBJ: createdir
	$(foreach file,$(CSRCS),$(CC) $(CFLAGS) -c -o $(OBJDIR)$(basename $(notdir $(file))).o $(file) $(NEWLINE))
	$(foreach file,$(CPPSRCS),$(CPP) $(CFLAGS) -c -o $(OBJDIR)$(basename $(notdir $(file))).o $(file) $(NEWLINE))

install_inc:
	$(foreach file, $(INSTALL_INC), $(INSTALL) $(file) $(INSTALL_INC_PATH)/$(notdir $(file)) $(NEWLINE))

##判断目录是否存在，不存在就创建
createdir:
	test -d $(OBJDIR) || mkdir -p $(OBJDIR)

clean: cleanobjs

cleanobjs:
	$(RM) $(OBJS) 

setup:
	(cd $(TOP);    \
	make install_inc;   \
	echo )

