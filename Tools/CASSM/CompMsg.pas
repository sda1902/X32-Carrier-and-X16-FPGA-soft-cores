unit CompMsg;

interface

const
// описатели типов ошибок
     TypeStrings: array [0..3] of String = ('Info: ',             //0
                                          'Warning: ',           //1
                                          'Error: ',             //2
                                          'Fatal: ');            //3
// строки сообщений информационного типа
     InfoStrings: array [0..20] of String = (     'Compiler started.',       //0
                                                  'Reading file ',            //1
                                                  'Return to loading file',   //2
                                            'Compiling the file',       //3
                                           'Compiling the project',     //4
                                           'Compiler shutdown.',        //5
                                           'Creating object file', //6
                                                     'Processing constant equations', //7
                                                       'Processing objects', //8
                                           'Searching the hardware description objects...', //9
                                           'Loading processor hardware map...', //10
                                                    'Total loaded lines :',  //11
                                           'Checking undefined lines...', //12
                                                     'Creating the object binary files.', //13
                                                     'Processing cross tables', //14
                                           'Compiling objects', //15
                                                      'Loading instruction references...', //16
                                           'Processing PDL objects...', //17
                                           'Creating binary processor map...', //18
                                           'Creating "Max+PLUS II" project files...', //19
                                                     'Compiling objects...' //20
                                           );

     // строки сообщений предупреждающего характера
     WarningStrings: array [0..14] of String = ('Empty file',         //0
                                              'No objects found for create object files.', //1
                                              'Using current directory for creating object files.', //2
                                              'Comments not present, but reserved word "Comment" found.', //3
                                              'Zero-length string data, ignoring operand.', //4
                                              'Missing operand', //5
                                                       'Ignore empty variable.', //6
                                                     'Object missing property record', //7
                                              'Project has no default instruction reference.', //8
                                              'Compiling project or file without default instruction reference.', //9
                                                         'Instruction field declared but not referenced', //10
                                                         'Empty object',     //11
                                              'Duplicate parameters set found.', //12
                                              'Empty parameters set.', //13
                                              'Can'+''''+'t create binary file because object required a built-in cross-table' //14
                                              );

     // строки сообщений об ошибках
     ErrorStrings: array [0..84] of String = (  'Source text already declared',     //0
                                            'Incorrect source declaration',      //1
                                            'Missing source name',               //2
                                            'This is a test error message.', //3
                                            'Illegal constant name definition.',             //4
                                                     'Missing a constant name or value.',                      //5
                                                     'Constant already defined.',                       //6
                                                      'Missing object name.',                            //7
                                            'Name of object has space symbols.', //8
                                            'Illegal "endof <object>" usage.', //9
                                                     'Unmatched end of object.', //10
                                            'Object already defined.', //11
                                            'Unexpected end of source', //12
                                            'Unexpected end of object',  //13
                                            'Inserted object not closed before', //14
                                            'Invalid object type found.',         //15
                                                     'Same declaration not allowed here.', //16
                                            '"OBJECT" or "PROCEDURE" must be defined before.', //17
                                                      'Missing alignment or start offset value.', //18
                                            '"INTERFACE" or "INSTRUCTION" or "FUNCTION" must be declared before "MODULE" declaration', //19
                                                  '"EndOf" statement missing object name.', //20
                                                  'Undefined line found.', //21
                                                  'Illegal symbols on line.', //22
                                                     'Source line exceeds limit of 252 symbols.',    //23
                                            ''''+'('+''''+' expected but object properties definition found', //24
                                                            'Incorrect object property definition',    //25
                                                            '")" before "(" found',     //26
                                                 'Unknown object properties word found',          //27
                                                     'Object property definition missing a property value', //28
                                                    'Illegal properties value found', //29
                                            'Comment definition not closed properly', //30
                                            'Missing end quote', //31
                                            'String data can'+''''+'t be placed as floating point data', //32
                                                    'Unknown word on line', //33
                                                    'Data format not defined, but data found', //34
                                            // строки, соответствующие ошибкам обработки арифметических выражений
                                            'Incorrect "(" and ")" usage', //35
                                            'Negative operand of square root', //36
                                            'Unknown math operator found', //37
                                                     'Math operator can'+''''+'t be placed here', //38
                                            'Value has expected of bounds', //39
                                            'Incorrect math function operand definition', //40
                                                       'Incorrect function usage', //41
                                            'Division by zero', //42
                                            'Math overflow', //43
                                            'Illegal operands of logarithmic function', //44
                                            'Value can'+''''+'t be represented in the integer format', //45
                                            'Array definition missing ")" terminator', //46
                                            'Array counter has illegal size', //47
                                            'Undefined line in the IDF file', //48
                                            'IDF section missing section identifier', //49
                                                         'Instruction reference missing operands and/or OpCode', //50
                                            'Instruction mnemonic has more than 31 symbol', //51
                                            'Instruction OpCode out of byte boundary', //52
                                                         'Field definition missing description block', //53
                                                         'Field definition has invalid description block', //54
                                            'Fields description block not closed properly', //55
                                            'Field description has empty description block', //56
                                            'Fields description block missing location or size parameter', //57
                                                    'Location or size parameter has illegal value', //58
                                                    'Missing operand mnemonic or value', //59
                                            'Operand mnemonic has more 47 symbols', //60
                                            'FP value can'+''''+'t be disposed in the filed that not equal 32 or 64, or 128 bits', //61
                                                      'Extra characters on line', //62
                                            'Instruction missing operands', //63
                                                         'Invalid operand of instruction', // 64
                                                     '"INCLUDE" missing file name', //65
                                                     'Invalid object declaration',   //66
                                                     'String or symbol data missing begining or ending delimiters', //67
                                                     'Illegal symbols in the object declaration', //68
                                                     'Object missing name',      //69;
                                                     'Variable or label allready exists.', //70
                                                     'Address operators not allowed here.', //71
                                            'Equation not found, but value expected.', //72
                                            'Symbol expected.', //73
                                                    'Object has no instruction reference.', //74
                                                    'Illegal format of instruction.', //75
                                            'Instruction field has not enought size for operand.', //76
                                            'Instruction field has illegal location for address placement.', //77
                                                         'Object not found.', //78
                                                         'Label not found.', //79
                                                   'Missing parameters or data.', //80
                                                     'Variable declaration not allowed here.', //81
                                            'Can'+''''+'t create binary file(s).', //82
                                                          'Illegal reserved word usage.', //83
                                            'Incorrect array reference.'    //84
                                            );

// строки фатальных ошибок
    FatalStrings: array [0..22] of String = ('Can'+''''+'t open source file',  //0
                                            'Not all data loaded from source file', //1
                                            'No source object specified',                    //2
                                                 'Any errors was detected.',      //3
                                                 'Nothing for compile.',                          //4
                                            'End of source not found...',                    //5
                                                 'Not enougth memory.',                           //6
                                                 'Any objects not closed.',                       //7
                                            'Processor reference not loaded.',               //8
                                                       'Objects pool overflow / or not enough memory.', //9
                                            'Too many constant processing iterations.',       //10
                                            'Can'+''''+'t create object file',                 //11
                                            'No instruction description files loaded', //12
                                            'Sections in IDF not closed', //13
                                            'IDF buffers pool overflow', //14
                                                 'Can'+''''+' find source file', //15
                                            'Not enought object parameters', //16
                                            'Invalid memory pointer. Memory allocation failure.', //17
                                            'Invalid processor map block', //18
                                            'Can'+''''+'t initialize "Max+PLUS II" interface system',  //19
                                            'Max+PLUS II compiler not located, choose "VipCompiler\Settings" to correct this error.', //20
                                                      'Can'+''''+'t create binary file.', //21
                                            'Can'+''''+'t determinate a project folder.' //22
                                            );

implementation


end.
