import 'dart:async';
import 'dart:io';
import 'dart:convert';

String kLPar = '(';
String kRPar = ')';
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

nreverse(lst) {
  var ret = kNil;
  while (lst['tag'] == 'cons') {
    var tmp = lst['cdr'];
    lst['cdr'] = ret;
    ret = lst;
    lst = tmp;
  }
  return ret;
}

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
    return readList(str.substring(1));
  } else if (str[0] == kQuote) {
    var tmp = read(str.substring(1));
    return [makeCons(makeSym('quote'), makeCons(tmp[0], kNil)), tmp[1]];
  }
  return readAtom(str);
}

readList(String str) {
  var ret = kNil;
  while (true) {
    str = skipSpaces(str);
    if (str.length == 0) {
      return makeError('unfinished parenthesis');
    } else if (str[0] == kRPar) {
      break;
    }
    var tmp = read(str);
    var elm = tmp[0];
    var next = tmp[1];
    if (elm['tag'] == 'error') {
      return [elm, ''];
    }
    ret = makeCons(elm, ret);
    str = next;
  }
  return [nreverse(ret), str.substring(1)];
}

printObj(obj) {
  var tag = obj['tag'];
  if (tag == 'num' || tag == 'sym' || tag == 'nil') {
    return obj['data'].toString();
  } else if (tag == 'error') {
    return '<error: ' + obj['data'] + '>';
  } else if (tag == 'cons') {
    return printList(obj);
  } else if (tag == 'subr' || tag == 'expr') {
    return tag;
  }
  return '<unknown>';
}

printList(obj) {
  String ret = '';
  bool first = true;
  while (obj['tag'] == 'cons') {
    if (first) {
      first = false;
    } else {
      ret += ' ';
    }
    ret += printObj(obj['car']);
    obj = obj['cdr'];
  }
  if (obj == kNil) {
    return '(' + ret + ')';
  }
  return '(' + ret + ' . ' + printObj(obj) + ')';
}

Stream readLine() => stdin.transform(UTF8.decoder).transform(new LineSplitter()
    );

void main() {
  stdout.write('> ');
  readLine().listen((String line) {
    print(printObj(read(line)[0]));
    stdout.write('> ');
  });
}
