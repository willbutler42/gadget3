open_bracket <- "("  # )

# formula_utils: Tools for manipulating calls/formula

# Turn a call into a formula, with environment env
call_to_formula <- function (c, env = parent.frame()) {
    formula(call("~", c), env = env)
}

# Merge (additions) into (env)
environment_merge <- function (env, additions, var_names = ls(envir = additions)) {
    for (n in var_names) {
        if (!exists(n, envir = env) && exists(n, envir = additions, inherits = FALSE)) {
            assign(n, get(n, envir = additions, inherits = FALSE), envir = env)
        }
    }
    return(NULL)
}

# Substitute within formulae, merging all environments together
f_substitute <- function (f, env, copy_all_env = FALSE) {
    env <- as.environment(env)
    # Copy f's environment to a new environment, ignore it's parent
    combined_env <- new.env(parent = emptyenv())
    environment_merge(combined_env, rlang::f_env(f))

    # For all formula substitutions...
    for (n in all.vars(f)) {
        o <- mget(n, envir = env, ifnotfound = list(NULL))[[1]]
        if (!rlang::is_formula(o)) next

        # NB: Bracket to avoid operator precedence issues:
        #     substitute(1 - recl / 3, list(recl = quote(4 + 16 / 1)))
        #     has bracketed implicitly and not part of the parse_tree.
        #     The C++ transliterator relies on these bracket nodes to avoid
        #     reinventing operator precedence.
        if (is_infix_call(rlang::f_rhs(o)) && !(as.character(rlang::f_rhs(o)[[1]]) %in% c("<-", "==", "!=", ">", "<", "<=", ">="))) {
            rlang::f_rhs(o) <- call(open_bracket, rlang::f_rhs(o))
        }

        # Replace formulae with the inner expression
        if (length(o) == 3) {
            assign(n, call('<-', o[[2]], o[[3]]), envir = env)
        } else {
            assign(n, o[[2]], envir = env)
        }

        # Combine it's environment with ours
        if (copy_all_env) {
            environment_merge(combined_env, rlang::f_env(o))
        } else {
            # Only copy things the formulae mentions
            vars_to_copy <- all.names(rlang::f_rhs(o), unique = TRUE)
            # If a stock_x__num (e.g.) variable is mentioned, also look for it's root
            vars_to_copy <- union(vars_to_copy, gsub("__.*", "", vars_to_copy))
            environment_merge(combined_env, rlang::f_env(o), var_names = vars_to_copy)
        }
    }

    # Make a substitute call out of our unevaluated formulae
    out <- eval(call("substitute", f, env))
    as.formula(out, env = combined_env)
}
# f_a <- (function () { t <- 3 ; y ~ {x + 2 ; parp} })()
# f_b <- (function () { q <- 2 ; z ~ q * 2 })()
# parse_tree(f_substitute(f_a, list(parp = f_b)))

f_find <- function (f, target_symbol) {
    if (is.call(f)) {
        return(c(
             (if (f[[1]] == target_symbol) list(f) else list()),
             do.call(c, lapply(f, function(x) f_find(x, target_symbol)))))
    }
    return(list())
}
# str(f_find(~ (2+(3+1)) * (4+4), as.symbol("+")))

# Descend through call f, when a symbol like key appears, call it's function to modify the call
call_replace <- function (f, ...) {
    modify_call_fns <- list(...)

    if (is.symbol(f)) {
        # Found a lone symbol, check if that needs translating
        modify_fn <- modify_call_fns[[as.character(f)]]
        if (length(modify_fn) > 0) {
            # TODO: To convert this into modify_fn(...) we need to differentiate
            #       modify_fn(quote(x)) and modify_fn(quote(x())) somehow
            # TODO: Do this using function signatures,
            #       "moo" = function (fn, arg1, arg2, ...) { ... }
            #       "moo" = function (sym) { ... }
            f <- modify_fn(f)
        }

        return(f)
    }

    if (!is.call(f)) return(f)

    # If there's a modify_fn that matches the symbol of this call, call it.
    # NB: Use deparse() to generate useful output for, e.g. Matrix::Matrix
    modify_fn <- modify_call_fns[[deparse(f[[1]])]]
    if (length(modify_fn) > 0) {
        f <- modify_fn(f)
        return(f)
    }

    # Recurse through all elements of this call
    out <- as.call(lapply(f, function (x) call_replace(x, ...)))

    # Put back all attributes (i.e. keep formula-ness)
    attributes(out) <- attributes(f)
    return(out)
}

f_concatenate <- function (list_of_f, parent = emptyenv(), wrap_call = NULL) {
    # Stack environments together
    e <- parent
    for (f in list_of_f) {
        # NB: Actions producing multiple steps will share environments. We
        # have to clone environments so they have separate parents.
        e <- rlang::env_clone(rlang::f_env(f), parent = e)
    }

    # Combine all functions into one expression
    out_call <- as.call(c(list(as.symbol("{")), lapply(unname(list_of_f), rlang::f_rhs)))
    if (!is.null(wrap_call)) {
        # Wrap inner call with outer
        out_call <- as.call(c(
            as.list(wrap_call),
            out_call))
    }
    formula(call("~", out_call), env = e)
}

# Perform optimizations on code within formulae, mostly for readability
f_optimize <- function (f) {
    # Simplify Basic arithmetic
    optim_arithmetic <- function (x) {
        if (!is.call(x) || length(x) != 3) return(x)

        op <- as.character(x[[1]])
        lhs <- f_optimize(x[[2]])
        rhs <- f_optimize(x[[3]])

        # Entirely remove any no-op arithmetic
        noop_value <- if (op == "*" || op == "/") 1 else 0
        if (is.numeric(rhs) && isTRUE(all.equal(rhs, noop_value))) {
            # x (op) 0/1 --> x
            return(lhs)
        }
        if (op %in% c("+", "*") && is.numeric(lhs) && isTRUE(all.equal(lhs, noop_value))) {
            # 0/1 (op) x --> x
            return(rhs)
        }

        call(op, lhs, rhs)
    }

    call_replace(f,
        "if" = function (x) {
            if (is.call(x) && ( isTRUE(x[[2]]) || identical(x[[2]], quote(!FALSE)) )) {
                # if(TRUE) exp --> exp
                return(f_optimize(x[[3]]))
            }
            if (is.call(x) && ( isFALSE(x[[2]]) || identical(x[[2]], quote(!TRUE)) )) {
                # if(FALSE) exp else exp_2 --> exp_2
                return (if (length(x) > 3) f_optimize(x[[4]]) else quote({}))
            }
            # Regular if, descend either side of expression
            x[[3]] <- f_optimize(x[[3]])
            if (length(x) > 3) x[[4]] <- f_optimize(x[[4]])
            return(x)
        },
        "{" = function (x) {
            if (!is.call(x)) return(x)
            # 1-statement braces just return
            if (length(x) == 2) return(f_optimize(x[[2]]))

            # Flatten any nested braces inside this brace
            as.call(do.call(c, lapply(x, function (part) {
                if (is.call(part)) {
                    # Optimize inner parts first
                    part <- f_optimize(part)
                    # NB: Check for symbol again---could have optimized down to a symbol
                    if (is.call(part) && part[[1]] == "{") {
                        # Nested brace operator, flatten this
                        # NB: "{ }" will be removed as a byproduct, since empty lists will dissapear
                        return(tail(as.list(part), -1))
                    }  # } - Match open brace of call
                }
                return(list(part))
            })))
        }, # } - Match open brace of call
        "(" = function (x) {  # ) - Match open bracket in condition
            if (!is.call(x)) return(x)

            # Optimise innards first
            inner <- f_optimize(x[[2]])

            # Remove brackets from symbols, double-bracked expressions and infix operators
            if (!is.call(inner) || inner[[1]] == open_bracket || !is_infix_call(inner)) {
                return(inner)
            }

            # Preserve the bracket by default
            return(call(open_bracket, inner))
        },
        "+" = optim_arithmetic,
        "-" = optim_arithmetic,
        "*" = optim_arithmetic,
        "/" = optim_arithmetic)
}

# Is (x) a call to an infix operator?
is_infix_call <- function (x) {
    if (!is.call(x)) return(FALSE)

    operator <- as.character(x[[1]])
    # https://cran.r-project.org/doc/manuals/r-release/R-lang.html#Infix-and-prefix-operators
    if (operator %in% c(
            '::',
            '$', '@',
            '^',
            '-', '+',
            ':',
            '%xyz%',
            '*', '/',
            '+', '-',
            '>', '>=', '<', '<=', '==', '!=',
            '!',
            '&', '&&',
            '|', '||',
            '~',
            '->', '->>',
            '<-', '<<-',
            '= ')) return(TRUE)
    return(grepl("^%.*%$", operator, perl = TRUE))
}

# Evaluate rhs of (f), using it's environment and (env_extras), using (env_parent) if one supplied
f_eval <- function (f, env_extras = list(), env_parent = g3_global_env) {
    # NB: Don't alter extras if it is an environment
    env <- as.environment(as.list(env_extras))
    parent.env(env) <- rlang::env_clone(rlang::f_env(f))

    # If supplied, replace the formula's parent env
    # NB: g3 formula objects generally don't have a sensible parent until g3_to_*, so
    #     we use g3_global_env by default for semi-sane behaviour
    if (is.environment(env_parent)) {
        parent.env(parent.env(env)) <- env_parent
    }
    eval(rlang::f_rhs(f), env)
}
