(vim.cmd "colorscheme kanagawa-wave")
(vim.cmd "filetype plugin on")
(vim.cmd "filetype indent on")
(vim.cmd "highlight WinSeparator guibg=None")
(vim.cmd "packadd cfilter")

(require :conf.settings)
(require :conf.pkgs)
(require :conf.nix-develop)
(require :conf.diagnostic)
(require :conf.events)

(tset _G :P (lambda [...]
              (let [inspected (icollect [_ v (ipairs [...])]
                                (vim.inspect v))]
                (each [_ printer (ipairs inspected)]
                  (print printer)))))

(local fzf (require :fzf-lua))
(local action (require :fzf-lua.actions))
(fzf.setup [:max-perf])

(local cope #(vim.cmd (.. ":copen " (math.floor (/ vim.o.lines 2.1)))))
(local oil (require :oil.actions))
(let [map vim.keymap.set]
  (map :n :- ::Oil<cr>)
  (map :n :_ #(oil.open_cwd.callback))
  (map :v :y "<Plug>OSCYankVisual|gvy")
  (map :n :<leader>qf cope)
  (map :n :<leader>q<BS> ":cclose<cr>")
  (map :n :<leader>ll ":lopen<cr>")
  (map :n :<leader>l<BS> ":lclose<cr>")
  (map :n "<M-h>" cope)
  (map :n "<M-j>" ":cnext<cr>")
  (map :n "<M-k>" ":cprev<cr>")
  (map :n :<M-l> ":Recompile<CR>")
  (map :n :<C-s>
       #(do
          (vim.api.nvim_feedkeys
            (vim.api.nvim_replace_termcodes
              ":Sh<up><c-f>" true false true)
            :n false)
          (vim.schedule #(do
                           (vim.cmd "let v:searchforward = 0")
                           (map :n :/ "/Sh.*" {:buffer true})
                           (map :n :? "?Sh.*" {:buffer true})))))
  (map :n :<C-x>
       #(do
          (vim.api.nvim_feedkeys
            (vim.api.nvim_replace_termcodes
              ":Compile<up><c-f>" true false true)
            :n false)
          (vim.schedule #(do
                           (vim.cmd "let v:searchforward = 0")
                           (map :n :/ "/Compile.*" {:buffer true})
                           (map :n :? "?Compile.*" {:buffer true})))))
  (map :n "[q" ":cprevious<cr>")
  (map :n "]q" ":cnext<cr>")
  (map :n "[x" ":lprevious<cr>")
  (map :n "]x" ":lnext<cr>")
  (map :n :<c-p> #(fzf.files))
  (map :n :<leader>xp #(fzf.files))
  (map :n "<leader>;" ":silent grep ")
  (map :n "<leader>'" ":silent args `fd `<left>")
  (map :n :<leader>xa #(fzf.args))
  (map :n :<leader>xb #(fzf.buffers
                         {:keymap {:fzf {"alt-a" "toggle-all"}}
                          :actions {:default {:fn action.buf_edit_or_qf}}}))
  (map :n :<leader>x<cr> #(vim.cmd "b #")))


(vim.api.nvim_create_user_command
  :NixEdit
  (fn [{: args}]
    (local f (io.popen (.. "nix eval --raw " vim.env.HOME "/flake#nixosConfigurations." (vim.fn.hostname) ".pkgs." args)))
    (vim.cmd (.. "e " (f:read))))
  {:nargs 1})

;; I like to use the qf to run a lot of stuff that prints junk
;; Here I just check if ansi control stuff is printed and reparse the lines with efm
(local qf
       (fn [{: id : title}]
         (fn [lines]
           (local s (fn [line pattern]
                      (let [(result n) (line:gsub pattern "")]
                         (match n
                           nil line
                           _ result))))
           (local prettify #(-> $1
                                (s "%c+%[[0-9:;<=>?]*[!\"#$%%&'()*+,-./]*[@A-Z%[%]^_`a-z{|}~]*;?[A-Z]?")))
           (vim.schedule
             #(do
                (local is-qf (= (vim.opt_local.buftype:get) "quickfix"))
                (local is-at-last-line (let [[row col] (vim.api.nvim_win_get_cursor 0)
                                             last-line (vim.api.nvim_buf_line_count 0)]
                                         (do
                                           (= row last-line))))
                (vim.fn.setqflist
                  [] :a
                  {: id : title
                   :lines
                   (icollect [l lines]
                     (do
                       (if (not= l "")
                           (prettify l))))})
                (if (or
                      (not is-qf)
                      (and is-at-last-line is-qf))
                    (vim.cmd ":cbottom")))))))

(var last_job_state nil)
(var last_job_thunk nil)
(local qfjob
       (fn [cmd stdin]
         (local title (table.concat cmd " "))
         (vim.fn.setqflist [] " " {: title})
         (local add2qf (qf (vim.fn.getqflist {:id 0 :title 1})))
         (set
           last_job_state
           (vim.system
                cmd
                {: stdin
                 :stdout (fn [err data]
                           (if data
                               (add2qf (string.gmatch data "[^\n]+"))))
                 :stderr (fn [err data]
                           (if data
                               (add2qf (string.gmatch data "[^\n]+"))))}
                (fn [obj]
                 (vim.schedule
                   #(do
                      (set winnr (vim.fn.winnr))
                      (if (not= obj.code 0)
                          (do
                            (cope)
                            (if (not= (vim.fn.winnr) winnr)
                                (do
                                  (vim.notify (.. title " failed, going back"))
                                  (vim.cmd "wincmd p | cbot"))
                                (vim.notify (.. title "failed, going back"))))
                          (vim.notify (.. "\"" title "\" succeeded!"))))))))))

(vim.api.nvim_create_user_command
  :Compile
  (fn [cmd]
    (local thunk #(qfjob cmd.fargs nil))
    (set last_job_thunk thunk)
    (thunk))
  {:nargs :* :bang true :complete :shellcmd})
(vim.api.nvim_create_user_command
  :Sh
  (fn [cmd]
    (local thunk #(qfjob [:sh :-c cmd.args] nil))
    (set last_job_thunk thunk)
    (thunk))
  {:nargs :* :bang true :complete :shellcmd})
(vim.api.nvim_create_user_command
  :Recompile
  (fn []
    (if (= nil last_job_state)
        (vim.notify "nothing to recompile")
        (if (not (last_job_state:is_closing))
            (vim.notify "Last job not finished")
            (last_job_thunk))))
  {:bang true})
(vim.api.nvim_create_user_command
  :Stop
  (fn []
    (if (not= nil last_job_state)
        (do
          (last_job_state:kill)
          (vim.notify "killed job"))
        (vim.notify "nothing to do")))
  {:bang true})
(vim.api.nvim_create_user_command
  :Args
  (fn [obj]
    (if (not= 0 (length obj.fargs))
        (do
          (local thunk #(qfjob [:sh :-c obj.args] (vim.fn.argv)))
          (set last_job_thunk thunk)
          (thunk))))
  {:nargs :* :bang true :complete :shellcmd})
