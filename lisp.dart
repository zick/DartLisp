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

pairlis(lst1, lst2) {
  var ret = kNil;
  while (lst1['tag'] == 'cons' && lst2['tag'] == 'cons') {
    ret = makeCons(makeCons(lst1['car'], lst2['car']), ret);
    lst1 = lst1['cdr'];
    lst2 = lst2['cdr'];
  }
  return nreverse(ret);
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
      return [makeError('unfinished parenthesis'), ''];
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

findVar(sym, env) {
  while (env['tag'] == 'cons') {
    var alist = env['car'];
    while (alist['tag'] == 'cons') {
      if (alist['car']['car'] == sym) {
        return alist['car'];
      }
      alist = alist['cdr'];
    }
    env = env['cdr'];
  }
  return kNil;
}

var g_env = makeCons(kNil, kNil);

addToEnv(sym, val, env) {
  env['car'] = makeCons(makeCons(sym, val), env['car']);
}

eval(obj, env) {
  var tag = obj['tag'];
  if (tag == 'nil' || tag == 'num' || tag == 'error') {
    return obj;
  } else if (tag == 'sym') {
    var bind = findVar(obj, env);
    if (bind == kNil) {
      return makeError(obj['data'] + ' has no value');
    }
    return bind['cdr'];
  }

  var op = safeCar(obj);
  var args = safeCdr(obj);
  if (op == makeSym('quote')) {
    return safeCar(args);
  } else if (op == makeSym('if')) {
    if (eval(safeCar(args), env) == kNil) {
      return eval(safeCar(safeCdr(safeCdr(args))), env);
    }
    return eval(safeCar(safeCdr(args)), env);
  } else if (op == makeSym('lambda')) {
    return makeExpr(args, env);
  } else if (op == makeSym('defun')) {
    var expr = makeExpr(safeCdr(args), env);
    var sym = safeCar(args);
    addToEnv(sym, expr, g_env);
    return sym;
  }
  return apply(eval(op, env), evlis(args, env), env);
}

evlis(lst, env) {
  var ret = kNil;
  while (lst['tag'] == 'cons') {
    var elm = eval(lst['car'], env);
    if (elm['tag'] == 'error') {
      return elm;
    }
    ret = makeCons(elm, ret);
    lst = lst['cdr'];
  }
  return nreverse(ret);
}

progn(body, env) {
  var ret = kNil;
  while (body['tag'] == 'cons') {
    ret = eval(body['car'], env);
    body = body['cdr'];
  }
  return ret;
}

apply(fn, args, env) {
  if (fn['tag'] == 'error') {
    return fn;
  } else if (args['tag'] == 'error') {
    return args;
  } else if (fn['tag'] == 'subr') {
    return fn['data'](args);
  } else if (fn['tag'] == 'expr') {
    return progn(fn['body'], makeCons(pairlis(fn['args'], args), fn['env']));
  }
  return makeError('noimpl');
}

subrCar(args) => safeCar(safeCar(args));

subrCdr(args) => safeCdr(safeCar(args));

subrCons(args) => makeCons(safeCar(args), safeCar(safeCdr(args)));

Stream readLine() => stdin.transform(UTF8.decoder).transform(new LineSplitter()
    );

void main() {
  addToEnv(makeSym('car'), makeSubr(subrCar), g_env);
  addToEnv(makeSym('cdr'), makeSubr(subrCdr), g_env);
  addToEnv(makeSym('cons'), makeSubr(subrCons), g_env);
  addToEnv(makeSym('t'), makeSym('t'), g_env);

  stdout.write('> ');
  readLine().listen((String line) {
    print(printObj(eval(read(line)[0], g_env)));
    stdout.write('> ');
  });
}
