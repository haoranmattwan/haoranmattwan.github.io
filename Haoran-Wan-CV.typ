// Simple numbering for non-book documents
#let equation-numbering = "(1)"
#let callout-numbering = "1"
#let subfloat-numbering(n-super, subfloat-idx) = {
  numbering("1a", n-super, subfloat-idx)
}

// Theorem configuration for theorion
// Simple numbering for non-book documents (no heading inheritance)
#let theorem-inherited-levels = 0

// Theorem numbering format (can be overridden by extensions for appendix support)
// This function returns the numbering pattern to use
#let theorem-numbering(loc) = "1.1"

// Default theorem render function
#let theorem-render(prefix: none, title: "", full-title: auto, body) = {
  if full-title != "" and full-title != auto and full-title != none {
    strong[#full-title.]
    h(0.5em)
  }
  body
}
// Some definitions presupposed by pandoc's typst output.
#let content-to-string(content) = {
  if content.has("text") {
    content.text
  } else if content.has("children") {
    content.children.map(content-to-string).join("")
  } else if content.has("body") {
    content-to-string(content.body)
  } else if content == [ ] {
    " "
  }
}

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms.item: it => block(breakable: false)[
  #text(weight: "bold")[#it.term]
  #block(inset: (left: 1.5em, top: -0.4em))[#it.description]
]

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let fields = old_block.fields()
  let _ = fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => {
          let subfloat-idx = quartosubfloatcounter.get().first() + 1
          subfloat-numbering(n-super, subfloat-idx)
        })
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => block({
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          })

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let children = old_title_block.body.body.children
  let old_title = if children.len() == 1 {
    children.at(0)  // no icon: title at index 0
  } else {
    children.at(1)  // with icon: title at index 1
  }

  // TODO use custom separator if available
  // Use the figure's counter display which handles chapter-based numbering
  // (when numbering is a function that includes the heading counter)
  let callout_num = it.counter.display(it.numbering)
  let new_title = if empty(old_title) {
    [#kind #callout_num]
  } else {
    [#kind #callout_num: #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block,
    block_with_new_content(
      old_title_block.body,
      if children.len() == 1 {
        new_title  // no icon: just the title
      } else {
        children.at(0) + new_title  // with icon: preserve icon block + new title
      }))

  align(left, block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1)))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color,
        width: 100%,
        inset: 8pt)[#if icon != none [#text(icon_color, weight: 900)[#icon] ]#title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}




#let article(
  title: none,
  subtitle: none,
  authors: none,
  keywords: (),
  date: none,
  abstract-title: none,
  abstract: none,
  thanks: none,
  cols: 1,
  lang: "en",
  region: "US",
  font: none,
  fontsize: 11pt,
  title-size: 1.5em,
  subtitle-size: 1.25em,
  heading-family: none,
  heading-weight: "bold",
  heading-style: "normal",
  heading-color: black,
  heading-line-height: 0.65em,
  mathfont: none,
  codefont: none,
  linestretch: 1,
  sectionnumbering: none,
  linkcolor: none,
  citecolor: none,
  filecolor: none,
  toc: false,
  toc_title: none,
  toc_depth: none,
  toc_indent: 1.5em,
  doc,
) = {
  // Set document metadata for PDF accessibility
  set document(title: title, keywords: keywords)
  set document(
    author: authors.map(author => content-to-string(author.name)).join(", ", last: " & "),
  ) if authors != none and authors != ()
  set par(
    justify: true,
    leading: linestretch * 0.65em
  )
  set text(lang: lang,
           region: region,
           size: fontsize)
  set text(font: font) if font != none
  show math.equation: set text(font: mathfont) if mathfont != none
  show raw: set text(font: codefont) if codefont != none

  set heading(numbering: sectionnumbering)

  show link: set text(fill: rgb(content-to-string(linkcolor))) if linkcolor != none
  show ref: set text(fill: rgb(content-to-string(citecolor))) if citecolor != none
  show link: this => {
    if filecolor != none and type(this.dest) == label {
      text(this, fill: rgb(content-to-string(filecolor)))
    } else {
      text(this)
    }
   }

  let has-title-block = title != none or (authors != none and authors != ()) or date != none or abstract != none
  if has-title-block {
    place(
      top,
      float: true,
      scope: "parent",
      clearance: 4mm,
      block(below: 1em, width: 100%)[

        #if title != none {
          align(center, block(inset: 2em)[
            #set par(leading: heading-line-height) if heading-line-height != none
            #set text(font: heading-family) if heading-family != none
            #set text(weight: heading-weight)
            #set text(style: heading-style) if heading-style != "normal"
            #set text(fill: heading-color) if heading-color != black

            #text(size: title-size)[#title #if thanks != none {
              footnote(thanks, numbering: "*")
              counter(footnote).update(n => n - 1)
            }]
            #(if subtitle != none {
              parbreak()
              text(size: subtitle-size)[#subtitle]
            })
          ])
        }

        #if authors != none and authors != () {
          let count = authors.len()
          let ncols = calc.min(count, 3)
          grid(
            columns: (1fr,) * ncols,
            row-gutter: 1.5em,
            ..authors.map(author =>
                align(center)[
                  #author.name \
                  #author.affiliation \
                  #author.email
                ]
            )
          )
        }

        #if date != none {
          align(center)[#block(inset: 1em)[
            #date
          ]]
        }

        #if abstract != none {
          block(inset: 2em)[
          #text(weight: "semibold")[#abstract-title] #h(1em) #abstract
          ]
        }
      ]
    )
  }

  if toc {
    let title = if toc_title == none {
      auto
    } else {
      toc_title
    }
    block(above: 0em, below: 2em)[
    #outline(
      title: toc_title,
      depth: toc_depth,
      indent: toc_indent
    );
    ]
  }

  doc
}

#set table(
  inset: 6pt,
  stroke: none
)
#let brand-color = (:)
#let brand-color-background = (:)
#let brand-logo = (:)

#set page(
  paper: "us-letter",
  margin: (bottom: 1in,left: 1in,right: 1in,top: 1in,),
  numbering: "1",
  columns: 1,
)

#show: doc => article(
  lang: "en",
  font: ("EB Garamond",),
  fontsize: 11pt,
  linkcolor: [012169],
  toc_title: [Table of contents],
  toc_depth: 3,
  doc,
)

// Haoran (Matt) Wan, Academic CV
// Last revised October 2026.
// Render with: quarto render Haoran-Wan-CV.qmd
// Design: black text throughout; Duke Navy (#012169) is the only color,
// used for the name, section headings, section rules, and links.

#let navy = rgb("#012169")

#set document(
  title: "Haoran (Matt) Wan, Curriculum Vitae",
  author: "Haoran (Matt) Wan",
  keywords: ("behavioral science", "decision making", "discounting", "aging")
)
#set page(
  paper: "us-letter",
  margin: (left: 1in, right: 1in, top: 1in, bottom: 1in),
  // Running header on continuation pages only; page 1 carries the title block.
  header: context {
    if counter(page).get().first() > 1 {
      set text(size: 9.5pt)
      grid(
        columns: (1fr, 1fr),
        align: (left, right),
        [Haoran (Matt) Wan],
        [Curriculum Vitae, October 2026]
      )
    }
  },
  footer: context {
    align(center, text(size: 9.5pt)[#counter(page).get().first()])
  }
)
#set text(font: "EB Garamond", size: 11pt, fill: black)
#set par(justify: false, leading: 0.7em, spacing: 0.95em)
#show link: set text(fill: navy)

#let section(title) = {
  v(7pt)
  block(breakable: false, sticky: true, width: 100%, below: 0.8em)[
    #text(size: 13pt, weight: "bold", fill: navy)[#title]
    #v(-6pt)
    #line(length: 100%, stroke: 0.5pt + navy)
  ]
}

#let subsection(title) = {
  v(2pt)
  block(breakable: false, sticky: true, below: 0.75em)[
    #text(weight: "bold")[#title]
  ]
}

// Dated entry: description on the left, year(s) right-aligned on the right.
#let entry(date, body) = {
  block(breakable: false, width: 100%, above: 0.8em, below: 0.8em)[
    #grid(
      columns: (1fr, 0.95in),
      column-gutter: 0.15in,
      par(hanging-indent: 0.3in)[#body],
      align(right)[#date]
    )
  ]
}

// Reference-list entry with a hanging indent (APA style).
#let item(body) = {
  block(breakable: false, width: 100%, above: 0.95em, below: 0.95em)[
    #par(hanging-indent: 0.3in)[#body]
  ]
}

#let doi(id) = box(link("https://doi.org/" + id))

// Keep a heading together with the entries that follow it.
#let keep(body) = block(breakable: false, width: 100%, body)

// Title block
#align(center)[
  #text(size: 22pt, weight: "bold", fill: navy)[Haoran (Matt) Wan]
  #v(-10pt)
  #text(size: 10pt, tracking: 1.6pt)[CURRICULUM VITAE]
]
#v(-4pt)
#line(length: 100%, stroke: 0.5pt + navy)
#v(-3pt)

#grid(
  columns: (1fr, 1fr),
  column-gutter: 0in,
  [
    Assistant Professor of Behavioral Science \
    Duke Kunshan University \
    Division of Social Sciences \
    Kunshan, Jiangsu, China
  ],
  align(right)[
    #link("mailto:haoran.wan@dukekunshan.edu.cn")[#text("haoran.wan@dukekunshan.edu.cn")] \
    #link("https://haoranwan.com")[haoranwan.com] \
    ORCID #link("https://orcid.org/0000-0002-3434-3146")[0000-0002-3434-3146] \
    #link("https://scholar.google.com/citations?user=wOmVqukAAAAJ&hl=en")[Google Scholar] ·
    #link("https://github.com/haoranmattwan")[GitHub] ·
    #link("https://osf.io/ptvar/")[OSF]
  ]
)

#section([Positions and Appointments])

#entry([2026–Present], [
  Duke Kunshan University \
  Assistant Professor of Behavioral Science, Division of Social Sciences
])

#section([Education])

#entry([2026], [
  Washington University in St. Louis \
  Ph.D., Psychological & Brain Sciences, May 2026 \
  _Dissertation:_ “Age, income, and the discounting of delayed and probabilistic rewards: The roles of financial resources and attribute salience.” \
  Co-advisors: Leonard Green and Joel Myerson
])

#entry([2023], [
  Washington University in St. Louis \
  M.A., Psychological & Brain Sciences \
  _Thesis:_ “Discounting of delayed and probabilistic outcomes across the adult lifespan.” \
  Graduate Certificate, Quantitative Data Analysis
])

#entry([2021], [
  Reed College \
  B.A., Economics and Psychology
])

#section([Awards and Honors])

#entry([2023, 2025], [Sallie P. Asche Travel Award, Center for Vital Longevity.])
#entry([2022], [Tony Nevin Student Award, Society for the Quantitative Analyses of Behavior.])
#entry([2021], [Gerald M. Meier Award for Distinction in Economics, Reed College.])
#entry([2019–2021], [Commendation for Excellence, Reed College.])

#section([Fellowships and Research Support])

#entry([2026], [Faculty Start-up Fund, Duke Kunshan University.])
#entry([2025], [Pivot 314 Fellowship, Washington University in St. Louis. Professional development fellowship.])
#entry([2021–2026], [University Fellowship, Washington University in St. Louis. Doctoral funding fellowship.])
#entry([2020], [Student Summer Research Fellowship, Reed College. Undergraduate research fellowship.])
#entry([2017, 2018], [Opportunity Grants, Reed College. Undergraduate research fellowships.])

#keep[
#section([Peer-Reviewed Publications])

#text(size: 9.5pt, style: "italic")[Analysis code and open data for these articles are linked at #link("https://haoranwan.com/publications.html")[haoranwan.com/publications.html].]

#item([*Wan, H.*, Myerson, J., Green, L., Strube, M. J., & Hale, S. (2026). Age, income, and the discounting of delayed and probabilistic rewards. _Frontiers in Psychology, 17_, 1765142. #doi("10.3389/fpsyg.2026.1765142")])

#item([*Wan, H.*, Tan, L., & Hackenberg, T. D. (2026). Behavioral economic analysis of pigeons’ token accumulation and reinforcer demand in a laboratory-based token economy. _Journal of the Experimental Analysis of Behavior, 125_(2), e70095. #doi("10.1002/jeab.70095")])
]

#item([Myerson, J., Green, L., Vanderveldt, A., & *Wan, H.* (2026). Delay–probability asymmetry in discounting: An anomaly in multiattribute choice. _Journal of the Experimental Analysis of Behavior, 126_(1), e70123. #doi("10.1002/jeab.70123")])

#item([*Wan, H.*, Green, L., & Myerson, J. (2025). Brief assessments of delay discounting: Two-amount monetary choice and delayed losses questionnaires. _The Psychological Record, 75_, 591–597. #doi("10.1007/s40732-025-00665-w")])

#item([*Wan, H.*, Myerson, J., Green, L., Strube, M. J., & Hale, S. (2025). Age, income, and the discounting of delayed monetary losses. _The Journals of Gerontology: Series B, 80_(11), gbaf162. #doi("10.1093/geronb/gbaf162")])

#item([Oliveira, L., Green, L., Myerson, J., & *Wan, H.* (2025). Discounting of probabilistic food reinforcement by pigeons. _Journal of the Experimental Analysis of Behavior, 124_(1), e70042. #doi("10.1002/jeab.70042")])

#item([*Wan, H.*, Green, L., & Myerson, J. (2024). Delayed monetary losses: Do different procedures and discounting measures assess the same construct? _Behavioural Processes, 222_, 105101. #doi("10.1016/j.beproc.2024.105101")])

#item([*Wan, H.*, Myerson, J., Green, L., Strube, M. J., & Hale, S. (2024). Age-related differences in delay discounting: Income matters. _Psychology and Aging, 39_(6), 632–643. #doi("10.1037/pag0000818")])

#item([*Wan, H.*, Myerson, J., & Green, L. (2023). Individual differences in degree of discounting: Do different procedures and measures assess the same construct? _Behavioural Processes, 208_, 104864. #doi("10.1016/j.beproc.2023.104864")])

#item([Schulingkamp, R., *Wan, H.*, & Hackenberg, T. D. (2023). Social familiarity and reinforcement value: A behavioral-economic analysis of demand for social interaction with cagemate and non-cagemate female rats. _Frontiers in Psychology, 14_, 1158365. #doi("10.3389/fpsyg.2023.1158365")])

#item([Kirkman, C., *Wan, H.*, & Hackenberg, T. D. (2022). A behavioral-economic analysis of demand and preference for social and food reinforcement in rats. _Learning and Motivation, 77_, 101780. #doi("10.1016/j.lmot.2021.101780")])

#item([*Wan, H.*, Kirkman, C. F., Jensen, G., & Hackenberg, T. D. (2021). Failure to find altruistic food sharing in rats. _Frontiers in Psychology, 12_, 696025. #doi("10.3389/fpsyg.2021.696025")])

#keep[
#section([In Preparation])

#item([*Wan, H.* Age, income, and the discounting of rewards that are both delayed and probabilistic: The effects of financial and cognitive resources. _Manuscript in preparation._])

#item([*Wan, H.*, Myerson, J., & Green, L. Asymmetric conditioning in the discounting of delayed, probabilistic rewards: A test of three combination rules. _Manuscript in preparation._])

#item([*Wan, H.*, Myerson, J., & Green, L. Delay and probability discounting: From standard to more complex, multi-attribute choice options. _Book chapter in preparation._])
]

#keep[
#section([Presentations])

#subsection([Conference Talks])

#item([*Wan, H.*, Myerson, J., & Green, L. (2022, May). _Comparison of the adjusting-amount procedure and the monetary choice questionnaire for measuring delay discounting._ 44th Annual Meeting of the Society for the Quantitative Analyses of Behavior, Boston, MA.])
]

#item([Hackenberg, T. D., Kirkman, C. F., *Wan, H.*, & Franceschini, C. (2019, September). _Behavioral economics of food and social reinforcement._ 10th International Meeting of the Association for Behavior Analysis International, Stockholm, Sweden.])

#subsection([Conference Posters])

#item([*Wan, H.*, Green, L., & Myerson, J. (2025, May). _Brief assessments of delay discounting: Two-amount monetary choice and delayed losses questionnaires._ 51st Annual Convention of the Association for Behavior Analysis International, Washington, DC.])

#item([*Wan, H.*, Green, L., Myerson, J., Strube, M., Hale, S., & Chen, D. (2025, February). _Age, income, and the discounting of delayed monetary losses._ 8th Dallas Aging and Cognition Conference, Dallas, TX.])

#item([*Wan, H.*, Green, L., & Myerson, J. (2024, May). _Discounting delayed losses: Do different procedures and measures assess the same construct?_ 50th Annual Convention of the Association for Behavior Analysis International, Philadelphia, PA.])

#item([*Wan, H.*, Myerson, J., Green, L., & Strube, M. (2024, May). _Discounting of rewards that are both delayed and probabilistic: A comparison of models._ 46th Annual Meeting of the Society for the Quantitative Analyses of Behavior, Philadelphia, PA.])

#item([*Wan, H.*, Green, L., & Myerson, J. (2023, May). _Changes in discounting of gains and losses across adulthood._ 49th Annual Convention of the Association for Behavior Analysis International, Denver, CO.])

#item([*Wan, H.*, Schulingkamp, R., & Hackenberg, T. (2023, May). _Social familiarity and reinforcement value: A behavioral-economic analysis of demand for social interaction in rats._ 45th Annual Meeting of the Society for the Quantitative Analyses of Behavior, Denver, CO.])

#item([*Wan, H.*, Green, L., Myerson, J., Strube, M., & Hale, S. (2023, February). _The effects of age and income on discounting of delayed rewards._ 7th Dallas Aging and Cognition Conference, Dallas, TX.])

#item([Cao, A., Tan, L., *Wan, H.*, & Hackenberg, T. D. (2022, May). _Own- and cross-price demand elasticity with specific and generalized conditioned reinforcers in a token economy with pigeons._ 44th Annual Meeting of the Society for the Quantitative Analyses of Behavior, Boston, MA.])

#item([*Wan, H.*, Tan, L., & Hackenberg, T. D. (2021, May). _Economic analysis of pigeons’ token production, exchange, and accumulation in a laboratory-based token economy._ 43rd Annual Meeting of the Society for the Quantitative Analyses of Behavior (virtual).])

#item([*Wan, H.*, Kirkman, C. F., Franceschini, C., & Hackenberg, T. D. (2019, May). _Failure to find altruistic behavior in rats._ 45th Annual Convention of the Association for Behavior Analysis International, Chicago, IL.])

#subsection([University Talks and Panels])

#item([*Wan, H.* (2026, September). _Is AI making us stupid?_ \[Panel discussion\]. University Dialogue Series, Duke Kunshan University, Kunshan, China.])

#item([*Wan, H.* (2023, April). _The effects of age and income on the discounting of delayed rewards._ Washington University in St. Louis, St. Louis, MO.])

#item([*Wan, H.* (2021, December). _Comparison of the monetary choice questionnaire and the adjusting-amount procedure for measuring delay discounting._ Washington University in St. Louis, St. Louis, MO.])

#section([Teaching Experience])

#entry([2026–2027], [
  Instructor, Duke Kunshan University \
  BEHAVSCI 101: Introduction to Behavioral Science (Fall 2026, Spring 2027) \
  BEHAVSCI 202: Institutions, Groups, and Society (Fall 2026, Spring 2027)
])

#entry([2025], [
  Graduate Teaching Assistant, Washington University in St. Louis \
  PSYCH 5068: Hierarchical Linear Models (M. J. Strube)
])

#entry([2024], [
  Lecturer, Washington University in St. Louis \
  PSYCH 102: First-Year Opportunity — Contemporary Issues in Psychology
])

#entry([2022–2024], [
  Assistant to Instructor, Washington University in St. Louis \
  PSYCH 3890: Advanced Psychological Statistics (S. Cooper & J. Jackson) \
  PSYCH 5068: Hierarchical Linear Models (M. J. Strube) \
  PSYCH 361: Psychology of Learning (L. Green)
])

#entry([2020–2021], [
  Teaching Assistant, Reed College \
  ECON 201: Introduction to Economic Analysis (D. Hare) \
  PSYCH 203/373: Learning & Comparative Psychology / Learning (T. Hackenberg)
])

#section([Research Mentoring])

#entry([2025], [Mars, W. “Discounting of probabilistic losses across the adult lifespan.” Research project, Washington University in St. Louis.])
#entry([2025], [Chen, D. “Age, income, and the discounting of delayed monetary losses.” Research project, Washington University in St. Louis.])
#entry([2024], [Salazar, S. “From simple to complex: The predictive validity of reward discounting in financial and health domains.” Research project, Washington University in St. Louis.])
#entry([2023], [Rosenthal, D. “Do you (scarcity) mind(set)?: A subjective examination of scarcity theory.” Senior honors thesis, Washington University in St. Louis.])
#entry([2022], [Sheldon, M. “The relation between probability and delay discounting: What is the immediate probabilistic value of a delayed reward?” Honors thesis, Washington University in St. Louis.])

#keep[
#section([Academic and Professional Service])

#subsection([Ad Hoc Reviewer])

_Journal of the Experimental Analysis of Behavior_ \
_Behavioural Processes_

#subsection([Professional Service])

#entry([2024], [Judge, 29th Graduate Student Research Symposium, Washington University in St. Louis.])
#entry([2023], [Volunteer, Society for the Quantitative Analyses of Behavior.])
#entry([2022–2023], [Chair, Graduate Student Brown Bag Series, Department of Psychological & Brain Sciences, Washington University in St. Louis.])
]

#keep[
#section([Industry Experience])

#entry([2025], [Data Scientist & Software Engineer, Swipesum, St. Louis, MO.])
#entry([2024], [Quantitative Medicine Analyst, Critical Path Institute, Tucson, AZ.])
#entry([2019], [Legal & Fixed-Income Analyst, Shenzhen Stock Exchange, Shenzhen, China.])
]

#keep[
#section([Professional Development])

#entry([2026], [Certificate in Innovative Curriculum Design and Pedagogy, Duke Kunshan University.])
#entry([2026], [Learning Innovation Fellowship (LIF) Program, Center for Teaching and Learning, Duke Kunshan University. Certificate of completion, August 2026.])
]

#keep[
#section([Professional Affiliations])

Association for Psychological Science \
Association for Behavior Analysis International \
Society for the Quantitative Analyses of Behavior \
American Psychological Association, Division 25 (Behavior Analysis)
]



