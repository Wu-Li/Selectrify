function parse(code, options) {
    var program, toString;

    toString = String;
    if (typeof code !== 'string' && !(code instanceof String)) {
        code = toString(code);
    }

    source = code;
    index = 0;
    lineNumber = (source.length > 0) ? 1 : 0;
    lineStart = 0;
    startIndex = index;
    startLineNumber = lineNumber;
    startLineStart = lineStart;
    length = source.length;
    lookahead = null;
    state = {
        allowIn: true,
        allowYield: true,
        labelSet: {},
        inFunctionBody: false,
        inIteration: false,
        inSwitch: false,
        lastCommentStart: -1,
        curlyStack: []
    };
    sourceType = 'script';
    strict = false;

    extra = {};
    if (typeof options !== 'undefined') {
        extra.range = (typeof options.range === 'boolean') && options.range;
        extra.loc = (typeof options.loc === 'boolean') && options.loc;
        extra.attachComment = (typeof options.attachComment === 'boolean') && options.attachComment;

        if (extra.loc && options.source !== null && options.source !== undefined) {
            extra.source = toString(options.source);
        }

        if (typeof options.tokens === 'boolean' && options.tokens) {
            extra.tokens = [];
        }
        if (typeof options.comment === 'boolean' && options.comment) {
            extra.comments = [];
        }
        if (typeof options.tolerant === 'boolean' && options.tolerant) {
            extra.errors = [];
        }
        if (extra.attachComment) {
            extra.range = true;
            extra.comments = [];
            extra.bottomRightStack = [];
            extra.trailingComments = [];
            extra.leadingComments = [];
        }
        if (options.sourceType === 'module') {
            // very restrictive condition for now
            sourceType = options.sourceType;
            strict = true;
        }
    }

    try {
        program = parseProgram();
        if (typeof extra.comments !== 'undefined') {
            program.comments = extra.comments;
        }
        if (typeof extra.tokens !== 'undefined') {
            filterTokenLocation();
            program.tokens = extra.tokens;
        }
        if (typeof extra.errors !== 'undefined') {
            program.errors = extra.errors;
        }
    } catch (e) {
        throw e;
    } finally {
        extra = {};
    }

    return program;
}
