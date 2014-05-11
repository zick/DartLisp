import 'dart:async';
import 'dart:io';
import 'dart:convert';

String kLPar = '(';
String kRPar = '(';
String kQuote = "'";
var kNil = {
  'tag': 'nil',
  'data': 'nil'
};

safeCar(obj) => (obj['tag'] == 'cons') ? obj['car'] : kNil;

safeCdr(obj) => (obj['tag'] == 'cons') ? obj['cdr'] : kNil;

makeError(String str) => {
  'tag': 'error',
  'data': str
};

Map<String, Object> sym_table = {};
makeSym(String str) {
  if (str == 'nil') {
    return kNil;
  } else if (!sym_table.containsKey(str)) {
    sym_table[str] = {
      'tag': 'sym',
      'data': str
    };
  }
  return sym_table[str];
}

makeNum(num n) => {
  'tag': 'num',
  'data': n
};

makeCons(a, d) => {
  'tag': 'cons',
  'car': a,
  'cdr': d
};

makeSubr(fn) => {
  'tag': 'subr',
  'data': fn
};

makeExpr(args, env) => {
  'tag': 'expr',
  'args': safeCar(args),
  'body': safeCdr(args),
  'env': env
};

isDelimiter(String c) => c == kLPar || c == kRPar || c == kQuote || new RegExp(
    r'\s+').hasMatch(c);

skipSpaces(String str) => str.replaceAll(new RegExp(r'^\s+'), '');

makeNumOrSym(String str) {
  try {
    return makeNum(int.parse(str));
  } catch (e) {
    return makeSym(str);
  }
}

readAtom(String str) {
  String next = '';
  for (var i = 0; i < str.length; i++) {
    if (isDelimiter(str[i])) {
      next = str.substring(i);
      str = str.substring(0, i);
      break;
    }
  }
  return [makeNumOrSym(str), next];
}

read(String str) {
  str = skipSpaces(str);
  if (str.length == 0) {
    return [makeError('empty input'), ''];
  } else if (str[0] == kRPar) {
    return [makeError('invalid syntax: ' + str), ''];
  } else if (str[0] == kLPar) {
    return [makeError('noimpl'), ''];
  } else if (str[0] == kQuote) {
    return [makeError('noimpl'), ''];
  }
  return readAtom(str);
}

Stream readLine() => stdin.transform(UTF8.decoder).transform(new LineSplitter()
    );

void main() {
  stdout.write('> ');
  readLine().listen((String line) {
    print(read(line));
    stdout.write('> ');
  });
}
