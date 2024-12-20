-- luasnip.lua

local ls = require "luasnip"
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

ls.add_snippets("go", {
  s("main", {
    t({
      "package main", "",
      "import (",
      '\t"fmt"',
      ")","",
      "func main() {",
      "\t"
    }),
    i(1, 'fmt.Println("Hello; World!")'),
    t({ "", "}" })
  }),

  s("fpl", {
    t("fmt.Println("), i(1), t(")")
  }),

  s("cerr", {
    t({
      "if err != nil {",
      "\tpanic(err)",
      "}"
    })
  })


  -- s("test", {
  --   t("you know"),
  --   t({"this", "is", "a", "test"})
  -- })
})

