import 'dart:async';
import 'dart:io';
import 'dart:convert';

String kLPar = '(';
String kRPar = ')';
String kQuote = "'";

class Nil {
  const Nil();
}

final kNil = const Nil();

safeCar(obj) => obj is Cons ? obj.car : kNil;
safeCdr(obj) => obj is Cons ? obj.cdr : kNil;

class Error {
  final data;
  Error(this.data);
}

makeError(String str) => new Error(str);

Map<String, Object> sym_table = {};

class Sym {
  final data;
  Sym(this.data);
}

makeSym(String str) {
  if (str == 'nil') {
    return kNil;
  } else if (!sym_table.containsKey(str)) {
    sym_table[str] = new Sym(str);
  }
  return sym_table[str];
}

final sym_t = makeSym('t');
final sym_quote = makeSym('quote');
final sym_if = makeSym('if');
final sym_lambda = makeSym('lambda');
final sym_defun = makeSym('defun');
final sym_setq = makeSym('setq');
final sym_loop = makeSym('loop');
final sym_return = makeSym('return');
var loop_val = kNil;

class Num {
  final data;
  Num(this.data);
}

makeNum(num n) => new Num(n);

class Cons {
  var car;
  var cdr;
  Cons(this.car, this.cdr);
}

makeCons(a, d) => new Cons(a, d);

class Subr {
  final data;
  Subr(this.data);
}

makeSubr(fn) => new Subr(fn);

class Expr {
  final args;
  final body;
  final env;
  Expr(this.args, this.body, this.env);
}

makeExpr(args, env) => new Expr(safeCar(args), safeCdr(args), env);

nreverse(lst) {
  var ret = kNil;
  while (lst is Cons) {
    var tmp = lst.cdr;
    lst.cdr = ret;
    ret = lst;
    lst = tmp;
  }
  return ret;
}

pairlis(lst1, lst2) {
  var ret = kNil;
  while (lst1 is Cons && lst2 is Cons) {
    ret = makeCons(makeCons(lst1.car, lst2.car), ret);
    lst1 = lst1.cdr;
    lst2 = lst2.cdr;
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
    return [makeError('invalid syntax: ${str}'), ''];
  } else if (str[0] == kLPar) {
    return readList(str.substring(1));
  } else if (str[0] == kQuote) {
    var tmp = read(str.substring(1));
    return [makeCons(sym_quote, makeCons(tmp[0], kNil)), tmp[1]];
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
    if (elm is Error) {
      return [elm, ''];
    }
    ret = makeCons(elm, ret);
    str = next;
  }
  return [nreverse(ret), str.substring(1)];
}

printObj(obj) {
  if (obj is Num || obj is Sym || obj is Nil) {
    return obj.data.toString();
  } else if (obj is Error) {
    return '<error: ${obj.data}>';
  } else if (obj is Cons) {
    return printList(obj);
  } else if (obj is Subr || obj is Expr) {
    return tag.runtimeType.toString();
  }
  return '<unknown>';
}

printList(obj) {
  String ret = '';
  bool first = true;
  while (obj is Cons) {
    if (first) {
      first = false;
    } else {
      ret += ' ';
    }
    ret += printObj(obj.car);
    obj = obj.cdr;
  }
  if (obj == kNil) {
    return '(${ret})';
  }
  return '(${ret} . ${printObj(obj)})';
}

findVar(sym, env) {
  while (env is Cons) {
    var alist = env.car;
    while (alist is Cons) {
      if (alist.car.car == sym) {
        return alist.car;
      }
      alist = alist.cdr;
    }
    env = env.cdr;
  }
  return kNil;
}

var g_env = makeCons(kNil, kNil);

addToEnv(sym, val, env) {
  env.car = makeCons(makeCons(sym, val), env.car);
}

eval(obj, env) {
  if (obj is Nil || obj is Num || obj is Error) {
    return obj;
  } else if (obj is Sym) {
    var bind = findVar(obj, env);
    if (bind == kNil) {
      return makeError('${obj.data} has no value');
    }
    return bind.cdr;
  }

  var op = safeCar(obj);
  var args = safeCdr(obj);
  if (op == sym_quote) {
    return safeCar(args);
  } else if (op == sym_if) {
    var c = eval(safeCar(args), env);
    if (c is Error) {
      return c;
    } else if (c == kNil) {
      return eval(safeCar(safeCdr(safeCdr(args))), env);
    }
    return eval(safeCar(safeCdr(args)), env);
  } else if (op == sym_lambda) {
    return makeExpr(args, env);
  } else if (op == sym_defun) {
    var expr = makeExpr(safeCdr(args), env);
    var sym = safeCar(args);
    addToEnv(sym, expr, g_env);
    return sym;
  } else if (op == sym_setq) {
    var val = eval(safeCar(safeCdr(args)), env);
    if (val is Error) {
      return val;
    }
    var sym = safeCar(args);
    var bind = findVar(sym, env);
    if (bind == kNil) {
      addToEnv(sym, val, g_env);
    } else {
      bind.cdr = val;
    }
    return val;
  } else if (op == sym_loop) {
    return loop(args, env);
  } else if (op == sym_return) {
    loop_val = eval(safeCar(args), env);
    return makeError('');
  }
  return apply(eval(op, env), evlis(args, env), env);
}

evlis(lst, env) {
  var ret = kNil;
  while (lst is Cons) {
    var elm = eval(lst.car, env);
    if (elm is Error) {
      return elm;
    }
    ret = makeCons(elm, ret);
    lst = lst.cdr;
  }
  return nreverse(ret);
}

progn(body, env) {
  var ret = kNil;
  while (body is Cons) {
    ret = eval(body.car, env);
    if (ret is Error) {
      return ret;
    }
    body = body.cdr;
  }
  return ret;
}

loop(body, env) {
  while (true) {
    var ret = progn(body, env);
    if (ret is Error) {
      if (ret.data == '') {
        return loop_val;
      }
      return ret;
    }
  }
}

apply(fn, args, env) {
  if (fn is Error) {
    return fn;
  } else if (args is Error) {
    return args;
  } else if (fn is Subr) {
    return fn.data(args);
  } else if (fn is Expr) {
    return progn(fn.body, makeCons(pairlis(fn.args, args), fn.env));
  }
  return makeError('noimpl');
}

subrCar(args) => safeCar(safeCar(args));

subrCdr(args) => safeCdr(safeCar(args));

subrCons(args) => makeCons(safeCar(args), safeCar(safeCdr(args)));

subrEq(args) {
  var x = safeCar(args);
  var y = safeCar(safeCdr(args));
  if (x is Num && y is Num) {
    if (x.data == y.data) {
      return sym_t;
    }
    return kNil;
  } else if (x == y) {
    return sym_t;
  }
  return kNil;
}

subrAtom(args) => (safeCar(args) is Cons) ? kNil : sym_t;

subrNumberp(args) => (safeCar(args) is Num) ? sym_t : kNil;

subrSymbolp(args) => (safeCar(args) is Sym) ? sym_t : kNil;

subrAddOrMul(fn, init_val) => (args) {
  var ret = init_val;
  while (args is Cons) {
    if (args.car is! Num) {
      return makeError('wrong type');
    }
    ret = fn(ret, args.car.data);
    args = args.cdr;
  }
  return makeNum(ret);
};
var subrAdd = subrAddOrMul((x, y) => x + y, 0);
var subrMul = subrAddOrMul((x, y) => x * y, 1);

subrSubOrDivOrMod(fn) => (args) {
  var x = safeCar(args);
  var y = safeCar(safeCdr(args));
  if (x is! Num || y is! Num) {
    return makeError('wrong type');
  }
  return makeNum(fn(x.data, y.data));
};
var subrSub = subrSubOrDivOrMod((x, y) => x - y);
var subrDiv = subrSubOrDivOrMod((x, y) => x / y);
var subrMod = subrSubOrDivOrMod((x, y) => x % y);

Stream readLine() => stdin.transform(UTF8.decoder).transform(new LineSplitter()
    );

void main() {
  addToEnv(makeSym('car'), makeSubr(subrCar), g_env);
  addToEnv(makeSym('cdr'), makeSubr(subrCdr), g_env);
  addToEnv(makeSym('cons'), makeSubr(subrCons), g_env);
  addToEnv(makeSym('eq'), makeSubr(subrEq), g_env);
  addToEnv(makeSym('atom'), makeSubr(subrAtom), g_env);
  addToEnv(makeSym('numberp'), makeSubr(subrNumberp), g_env);
  addToEnv(makeSym('symbolp'), makeSubr(subrSymbolp), g_env);
  addToEnv(makeSym('+'), makeSubr(subrAdd), g_env);
  addToEnv(makeSym('*'), makeSubr(subrMul), g_env);
  addToEnv(makeSym('-'), makeSubr(subrSub), g_env);
  addToEnv(makeSym('/'), makeSubr(subrDiv), g_env);
  addToEnv(makeSym('mod'), makeSubr(subrMod), g_env);
  addToEnv(sym_t, sym_t, g_env);

  stdout.write('> ');
  readLine().listen((String line) {
    print(printObj(eval(read(line)[0], g_env)));
    stdout.write('> ');
  });
}
