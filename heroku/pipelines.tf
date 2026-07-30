resource "heroku_pipeline" "blade_ruby_lang" {
  name = "blade-ruby-lang"

  owner {
    id   = "81e55aef-952b-440e-aaac-537d99c2b419"
    type = "team"
  }
}

resource "heroku_pipeline" "bugs_ruby_lang" {
  name = "bugs-ruby-lang"

  owner {
    id   = "81e55aef-952b-440e-aaac-537d99c2b419"
    type = "team"
  }
}

resource "heroku_pipeline" "rubyci" {
  name = "rubyci"

  owner {
    id   = "81e55aef-952b-440e-aaac-537d99c2b419"
    type = "team"
  }
}
