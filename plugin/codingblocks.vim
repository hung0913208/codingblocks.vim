" Default configuration
let s:output_buffer = "CodingBlocks"

" Function that opens or navigates to the output buffer.
function! s:OutputBufferOpen(name)
    let scr_bufnum = bufnr(a:name)
    if scr_bufnum == -1
        exe "new " . a:name
    else
        let scr_winnum = bufwinnr(scr_bufnum)
        if scr_winnum != -1
            if winnr() != scr_winnum
                exe scr_winnum . "wincmd w"
            endif
        else
            exe "split +buffer" . scr_bufnum
        endif
    endif
    call s:OutputBuffer()
endfunction

" After opening the output buffer, this sets some properties for it.
function! s:OutputBuffer()
    setlocal buftype=nofile
    setlocal bufhidden=hide
    setlocal noswapfile
    setlocal filetype=txt
endfunction

" check for python3
if has("python3")
python3 << EOF
import vim, json, base64, os, urllib.request


class Api(object):
    RUN = "https://ide-api.codingblocks.com/run"
    MAPPING = {
        "python": "py3",
	"cpp": "cpp",
	"c": "c",
	"kt": "kotlin",
	"java": "java8",
	"js": "nodejs10"
    }

    def __init__(self, action, source, language, arguments):
        self._arguments = arguments
        self._language = language
        self._action = action
        self._source = source

    @property
    def action(self):
        return self._action

    @property
    def language(self):
        if self._language in Api.MAPPING:
            return Api.MAPPING[self._language]
        else:
            raise AssertionError("don't support {}".format(self._language))

    @property
    def source(self):
        return self._source

    @property
    def arguments(self):
        return self._arguments

    def get(self, url, direct=False):
        req = urllib.request.Request(url)

        if direct is False:
            req.add_header("Content-Type", "application/json;charset=utf-8")
            req.add_header("Authorization", "Bearer undefined")
            req.add_header("Origin", "https://ide.codingblocks.com")
            req.add_header("TE", "Trailers")

        with urllib.request.urlopen(req) as resp:
            result = resp.read()

            if isinstance(result, str):
                return result
            else:
                return result.decode("utf-8")

    def post(self, url, data, direct=False):
        req = urllib.request.Request(url, data=data.encode("utf-8"))

        if direct is False:
            req.add_header("Content-Type", "application/json;charset=utf-8")
            req.add_header("Authorization", "Bearer undefined")
            req.add_header("Origin", "https://ide.codingblocks.com")
            req.add_header("TE", "Trailers")

        with urllib.request.urlopen(req) as resp:
            result = resp.read()

            if isinstance(result, str):
                return result
            else:
                return result.decode("utf-8")

    def call(self):
        if self.action == "run":
            self.__run__()

    def __run__(self):
        if self.source:
            with open(self.source) as fd:
                data = fd.read()
        else:
            data = '\n'.join([line for line in vim.current.buffer])

        data = base64.b64encode(data.encode("utf-8")).decode("utf-8")

        idresp = json.loads(self.post(Api.RUN, json.dumps({
                "lang": self.language,
                "input": self.arguments,
                "source": data + "==",
            })))

        if not "id" in idresp:
            raise AssertionError("request run but didn't see `id`")

        while True:
            retresp = json.loads(self.get("{}/{}".format(Api.RUN, idresp["id"])))

            if not "outputs" in retresp:
                raise AssertionError("request output but didn't see `outputs`")
            elif retresp["outputs"] is None:
                continue
            else:
                result = ""

            for link in retresp["outputs"]:
                io = json.loads(self.get(link, True))

                if io["stderr"]:
                    result += base64.b64decode(io["stderr"]).decode("utf-8")
                else:
                    result += base64.b64decode(io["stdout"]).decode("utf-8")
            else:
                print(result)
                break

class File(object):
    @staticmethod
    def abspath(file_path):
        if file_path is not None:
            path = os.path
            file_path = path.expanduser(file_path)
            if(not(path.isabs(file_path))):
                file_path = path.abspath(file_path)
        return file_path

    @staticmethod
    def extension(file_path):
        if file_path is not None:
            path = os.path
            filename, fileextension = path.splitext(file_path)
            fileextension = fileextension.replace('.','')
            return fileextension 


class VimInterface(object): 
    def __init__(self, buff=None):
        self.buff = buff

    def load(self, buffer_file=None):
        if buffer_file is None:
            vim.command("call s:OutputBufferOpen('%s')" % vim.eval("s:output_buffer"))
        else:
            vim.command("new %s" % File.abspath(buffer_file).replace(' ','\ '))

        buff = vim.current.buffer
        self.buff = buff

    def append(self, string):
        if isinstance(string, str) is False:
            string = string.decode("utf-8")

        if self.isloaded():
            lines = string.strip().split('\n')
            for line in lines:
                self.buff.append(line)

    def delete(self):
        if self.isloaded():
            del self.buff[:]

    def save(self):
        vim.command("w")

    def isloaded(self):
        if not self.buff:
            raise Exception("Buffer not loaded.")
        else:
            return True
EOF

function! s:CodingBlocks()
python3 << EOF
api = Api("run", None, vim.eval("&filetype"), "")
api.call()
EOF
endfunction
else
    echoerr "Codingblocks: Plugin needs to be compiled with python support."
    finish
endif

" commands
command! -nargs=? -complete=file CodingBlocks :call <SID>CodingBlocks()
