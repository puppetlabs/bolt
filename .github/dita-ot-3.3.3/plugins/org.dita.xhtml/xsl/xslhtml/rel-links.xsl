<?xml version="1.0" encoding="UTF-8" ?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2004, 2005 IBM Corporation

See the accompanying LICENSE file for applicable license.
-->

<xsl:stylesheet version="2.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:ditamsg="http://dita-ot.sourceforge.net/ns/200704/ditamsg"
                xmlns:related-links="http://dita-ot.sourceforge.net/ns/200709/related-links"
                xmlns:dita-ot="http://dita-ot.sourceforge.net/ns/201007/dita-ot"
                exclude-result-prefixes="xs related-links ditamsg dita-ot">

  <xsl:key name="linkdup"
           match="*[contains(@class, ' topic/link ')][not(ancestor::*[contains(@class, ' topic/linklist ')])]
                   [not(@role = ('child', 'parent', 'previous', 'next', 'ancestor', 'descendant'))]"
           use="concat(ancestor::*[contains(@class, ' topic/related-links ')]/parent::*[contains(@class, ' topic/topic ')]/@id,
                       ' ',
                       @href)"/>

  <xsl:param name="NOPARENTLINK" select="'no'" as="xs:string"/><!-- "no" and "yes" are valid values; non-'no' is ignored -->
  <xsl:param name="include.rellinks" select="'#default parent child sibling friend next previous cousin ancestor descendant sample external other'" as="xs:string"/>
  <xsl:variable name="include.roles" select="tokenize(normalize-space($include.rellinks), '\s+')" as="xs:string*"/>
  
  <!-- ========== Hooks for common user customizations ============== -->
  <!-- The following two templates are available for anybody who needs
     to put out an token at the start or end of a link, such as an
     icon to indicate links to PDF files or external web addresses. -->
  <xsl:template match="*" mode="add-link-highlight-at-start"/>
  <xsl:template match="*" mode="add-link-highlight-at-end"/>
  <xsl:template match="*" mode="add-xref-highlight-at-start"/>
  <xsl:template match="*" mode="add-xref-highlight-at-end"/>

  <!-- Override this template to add any standard link attributes.
     Called for all links. -->
  <xsl:template match="*" mode="add-custom-link-attributes"/>

  <!-- Override these templates to place some a prefix before generated
     child links, such as "Optional" for optional child links. Called
     for all child links. -->
  <xsl:template match="*" mode="related-links:ordered.child.prefix"/>
  <xsl:template match="*" mode="related-links:unordered.child.prefix"/>

  <!-- ========== End hooks for common user customizations ========== -->

  <!--template for xref-->
  <xsl:template match="*[contains(@class, ' topic/xref ')]" name="topic.xref">
    <xsl:choose>
      <xsl:when test="@href and normalize-space(@href)">
        <xsl:apply-templates select="." mode="add-xref-highlight-at-start"/>
        <a>
          <xsl:call-template name="commonattributes"/>
          <xsl:apply-templates select="." mode="add-linking-attributes"/>
          <xsl:apply-templates select="." mode="add-desc-as-hoverhelp"/>
          <!-- if there is text or sub element other than desc, apply templates to them
          otherwise, use the href as the value of link text. -->
          <xsl:choose>
            <xsl:when test="@type = 'fn'">
              <sup>
                <xsl:choose>
                  <xsl:when test="*[not(contains(@class, ' topic/desc '))] | text()">
                    <xsl:apply-templates select="*[not(contains(@class, ' topic/desc '))] | text()"/>
                    <!--use xref content-->
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:call-template name="href"/><!--use href text-->
                  </xsl:otherwise>
                </xsl:choose>
              </sup>
            </xsl:when>
            <xsl:otherwise>
              <xsl:choose>
                <xsl:when test="*[not(contains(@class, ' topic/desc '))] | text()">
                  <xsl:apply-templates select="*[not(contains(@class, ' topic/desc '))] | text()"/>
                  <!--use xref content-->
                </xsl:when>
                <xsl:otherwise>
                  <xsl:call-template name="href"/><!--use href text-->
                </xsl:otherwise>
              </xsl:choose>
            </xsl:otherwise>
          </xsl:choose>
        </a>
        <xsl:apply-templates select="." mode="add-xref-highlight-at-end"/>
      </xsl:when>
      <xsl:otherwise>
        <span>
          <xsl:call-template name="commonattributes"/>
          <xsl:apply-templates select="." mode="add-desc-as-hoverhelp"/>
          <xsl:apply-templates select="*[not(contains(@class, ' topic/desc '))] | text() | comment() | processing-instruction()"/>
        </span>
      </xsl:otherwise>
    </xsl:choose>

  </xsl:template>

  <!--create breadcrumbs for each grouping of ancestor links; include previous, next, and ancestor links, sorted by linkpool/related-links parent. If there is more than one linkpool that contains ancestors, multiple breadcrumb trails will be generated-->
  <xsl:template match="*[contains(@class, ' topic/related-links ')]" mode="breadcrumb">
    <xsl:for-each select="descendant-or-self::*[contains(@class, ' topic/related-links ') or contains(@class, ' topic/linkpool ')][*[@role = 'ancestor']]">
      <xsl:value-of select="$newline"/>
      <div class="breadcrumb">
        <xsl:if test="$include.roles = 'previous'">
          <!--output previous link first, if it exists-->
          <xsl:if test="*[@href][@role = 'previous']">
            <xsl:apply-templates select="*[@href][@role = 'previous'][1]" mode="breadcrumb"/>
          </xsl:if>
        </xsl:if>
        <!--if both previous and next links exist, output a separator bar-->
        <xsl:if test="$include.roles = 'previous' and $include.roles = 'next'">
          <xsl:if test="*[@href][@role = 'next'] and *[@href][@role = 'previous']">
            <xsl:text> | </xsl:text>
          </xsl:if>
        </xsl:if>
        <xsl:if test="$include.roles = 'next'">
          <!--output next link, if it exists-->
          <xsl:if test="*[@href][@role = 'next']">
            <xsl:apply-templates select="*[@href][@role = 'next'][1]" mode="breadcrumb"/>
          </xsl:if>
        </xsl:if>
        <xsl:if test="$include.roles = 'previous' and $include.roles = 'next' and $include.roles = 'ancestor'">
          <!--if we have either next or previous, plus ancestors, separate the next/prev from the ancestors with a vertical bar-->
          <xsl:if test="(*[@href][@role = 'next'] or *[@href][@role = 'previous']) and *[@href][@role = 'ancestor']">
            <xsl:text> | </xsl:text>
          </xsl:if>
        </xsl:if>
        <xsl:if test="$include.roles = 'ancestor'">
          <!--if ancestors exist, output them, and include a greater-than symbol after each one, including a trailing one-->
          <xsl:for-each select="*[@href][@role = 'ancestor']">
            <xsl:apply-templates select="."/>
            <xsl:text> &gt; </xsl:text>
          </xsl:for-each>
        </xsl:if>
      </div>
      <xsl:value-of select="$newline"/>
    </xsl:for-each>
  </xsl:template>

  <!--create prerequisite links with all dups eliminated. -->
  <xsl:template match="*[contains(@class, ' topic/related-links ')]" mode="prereqs">
    <!--if there are any prereqs create a list with dups-->
    <!--only create link if there is an href, its importance is required, and the role is compatible (don't want a prereq showing up for a "next" or "parent" link, for example) - remove dups-->
    <xsl:variable name="prereqs"
                  select="descendant::*[generate-id(.) = generate-id(key('link', related-links:link(.))[1])]
                                       [@href]
                                       [@importance = 'required' and (empty(@role) or @role = ('sibling', 'friend', 'previous', 'cousin'))]
                                       [not(ancestor::*[contains(@class, ' topic/linklist ')])]"/>
    <xsl:if test="exists($prereqs)">
      <xsl:value-of select="$newline"/>
      <dl class="prereqlinks">
        <xsl:value-of select="$newline"/>
        <dt class="prereq">
          <xsl:call-template name="getVariable">
            <xsl:with-param name="id" select="'Prerequisites'"/>
          </xsl:call-template>
        </dt>
        <xsl:value-of select="$newline"/>
        <xsl:apply-templates select="$prereqs" mode="prereqs"/>
      </dl>
      <xsl:value-of select="$newline"/>
    </xsl:if>
  </xsl:template>

  <!--main template for setting up all links after the body - applied to the related-links container-->
  <xsl:template match="*[contains(@class, ' topic/related-links ')]" name="topic.related-links">
    <nav role="navigation">
      <xsl:call-template name="commonattributes"/>
      <xsl:if test="$include.roles = ('child', 'descendant')">
        <xsl:call-template name="ul-child-links"/>
        <!--handle child/descendants outside of linklists in collection-type=unordered or choice-->
        <xsl:call-template name="ol-child-links"/>
        <!--handle child/descendants outside of linklists in collection-type=ordered/sequence-->
      </xsl:if>
      <xsl:if test="$include.roles = ('next', 'previous', 'parent')">
        <xsl:call-template name="next-prev-parent-links"/>
        <!--handle next and previous links-->
      </xsl:if>
      <!-- Group all unordered links (which have not already been handled by prior sections). Skip duplicate links. -->
      <!-- NOTE: The actual grouping code for related-links:group-unordered-links is common between
             transform types, and is located in ../common/related-links.xsl. Actual code for
             creating group titles and formatting links is located in XSL files specific to each type. -->
      <xsl:variable name="unordered-links" as="element()*">
       <xsl:apply-templates select="." mode="related-links:group-unordered-links">
         <xsl:with-param name="nodes"
                         select="descendant::*[contains(@class, ' topic/link ')]
                                              [not(related-links:omit-from-unordered-links(.))]
                                              [generate-id(.) = generate-id(key('hideduplicates', related-links:hideduplicates(.))[1])]"/>
       </xsl:apply-templates>
      </xsl:variable>
      <xsl:apply-templates select="$unordered-links"/>
      <!--linklists - last but not least, create all the linklists and their links, with no sorting or re-ordering-->
      <xsl:apply-templates select="*[contains(@class, ' topic/linklist ')]"/>
    </nav>
  </xsl:template>


  <!--children links - handle all child or descendant links except those in linklists or ordered collection-types.
Each child is indented, the linktext is bold, and the shortdesc appears in normal text directly below the link, to create a summary-like appearance.-->
  <xsl:template name="ul-child-links">
    <xsl:variable name="children"
                  select="descendant::*[contains(@class, ' topic/link ')]
                                       [@role = ('child', 'descendant')]
                                       [not(parent::*/@collection-type = 'sequence')]
                                       [not(ancestor::*[contains(@class, ' topic/linklist ')])]"/>
    <xsl:if test="$children">
      <xsl:value-of select="$newline"/>
      <ul class="ullinks">
        <xsl:value-of select="$newline"/>
        <!--once you've tested that at least one child/descendant exists, apply templates to only the unique ones-->
        <xsl:apply-templates select="$children[generate-id(.) = generate-id(key('link', related-links:link(.))[1])]"/>
      </ul>
      <xsl:value-of select="$newline"/>
    </xsl:if>
  </xsl:template>

  <!--children links - handle all child or descendant links in ordered collection-types.
  Children are displayed in a numbered list, with the target title as the cmd and the shortdesc as info, like a task.
  -->
  <xsl:template name="ol-child-links">
    <xsl:variable name="children"
                  select="descendant::*[contains(@class, ' topic/link ')]
                                       [@role = ('child', 'descendant')]
                                       [parent::*/@collection-type = 'sequence']
                                       [not(ancestor::*[contains(@class, ' topic/linklist ')])]"/>
    <xsl:if test="$children">
      <xsl:value-of select="$newline"/>
      <ol class="olchildlinks">
        <xsl:value-of select="$newline"/>
        <!--once you've tested that at least one child/descendant exists, apply templates to only the unique ones-->
        <xsl:apply-templates select="$children[generate-id(.) = generate-id(key('link', related-links:link(.))[1])]"/>
      </ol>
      <xsl:value-of select="$newline"/>
    </xsl:if>
  </xsl:template>

  <!--create the next and previous links, with accompanying parent link if any; create group for each unique parent, as well as for any next and previous links that aren't in the same group as a parent-->
  <xsl:template name="next-prev-parent-links">
    <xsl:for-each select="descendant::*[contains(@class, ' topic/link ')]
                                       [@role = ('parent', 'next', 'previous') and
                                        generate-id(.) = generate-id(key('link', related-links:link(.))[1])]/parent::*">
      <xsl:value-of select="$newline"/>
      <div class="familylinks">
        <xsl:value-of select="$newline"/>

        <xsl:if test="$NOPARENTLINK = 'no' and $include.roles = 'parent'">
          <xsl:choose>
            <xsl:when test="*[@href][@role = 'parent']">
              <xsl:for-each select="*[@href][@role = 'parent']">
                <div class="parentlink">
                  <xsl:apply-templates select="."/>
                </div>
                <xsl:value-of select="$newline"/>
              </xsl:for-each>
            </xsl:when>
            <xsl:otherwise>
              <xsl:for-each select="*[@href][@role = 'ancestor'][last()]">
                <div class="parentlink">
                  <xsl:call-template name="parentlink"/>
                </div>
                <xsl:value-of select="$newline"/>
              </xsl:for-each>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:if>

        <xsl:if test="$include.roles = 'previous'">
          <xsl:for-each select="*[@href][@role = 'previous']">
            <div class="previouslink">
              <xsl:apply-templates select="."/>
            </div>
            <xsl:value-of select="$newline"/>
          </xsl:for-each>
        </xsl:if>
        <xsl:if test="$include.roles = 'next'">
          <xsl:for-each select="*[@href][@role = 'next']">
            <div class="nextlink">
              <xsl:apply-templates select="."/>
            </div>
            <xsl:value-of select="$newline"/>
          </xsl:for-each>
        </xsl:if>
      </div>
      <xsl:value-of select="$newline"/>
    </xsl:for-each>
  </xsl:template>

  <!-- Override no-name group wrapper template for HTML: output "Related Information" in a <linklist>. -->
  <xsl:template match="*[contains(@class, ' topic/link ')]" mode="related-links:result-group" name="related-links:group-result."
                as="element()">
    <xsl:param name="links" as="node()*"/>
    <xsl:if test="exists($links)">
      <linklist class="- topic/linklist " outputclass="relinfo">
        <xsl:copy-of select="ancestor-or-self::*[@xml:lang][1]/@xml:lang"/>
        <title class="- topic/title ">
          <xsl:call-template name="getVariable">
            <xsl:with-param name="id" select="'Related information'"/>
          </xsl:call-template>
        </title>
        <xsl:copy-of select="$links"/>
      </linklist>
    </xsl:if>
  </xsl:template>

  <!-- Links with @type="topic" belong in no-name group. -->
  <xsl:template match="*[contains(@class, ' topic/link ')][@type = 'topic']" mode="related-links:get-group-priority"
                name="related-links:group-priority.topic" priority="2"
                as="xs:integer">
    <xsl:call-template name="related-links:group-priority."/>
  </xsl:template>
  <xsl:template match="*[contains(@class, ' topic/link ')][@type = 'topic']" mode="related-links:get-group"
                name="related-links:group.topic" priority="2"
                as="xs:string">
    <xsl:call-template name="related-links:group."/>
  </xsl:template>
  <xsl:template match="*[contains(@class, ' topic/link ')][@type = 'topic']" mode="related-links:result-group"
                name="related-links:group-result.topic" priority="2">
    <xsl:param name="links" as="node()*"/>
    <xsl:call-template name="related-links:group-result.">
      <xsl:with-param name="links" select="$links"/>
    </xsl:call-template>
  </xsl:template>

  <!--calculate href-->
  <xsl:template name="href">
    <xsl:apply-templates select="." mode="determine-final-href"/>
  </xsl:template>
  <xsl:template match="*" mode="determine-final-href">
    <xsl:choose>
      <xsl:when test="not(normalize-space(@href)) or empty(@href)"/>
      <!-- For non-DITA formats - use the href as is -->
      <xsl:when test="(empty(@format) and @scope = 'external') or (@format and not(@format = 'dita'))">
        <xsl:value-of select="@href"/>
      </xsl:when>
      <!-- For DITA - process the internal href -->
      <xsl:when test="starts-with(@href, '#')">
        <xsl:text>#</xsl:text>
        <xsl:value-of select="dita-ot:generate-id(dita-ot:get-topic-id(@href), dita-ot:get-element-id(@href))"/>
      </xsl:when>
      <!-- It's to a DITA file - process the file name (adding the html extension)
    and process the rest of the href -->
      <xsl:when test="(empty(@scope) or @scope = ('local', 'peer')) and (empty(@format) or @format = 'dita')">
        <xsl:call-template name="replace-extension">
          <xsl:with-param name="filename" select="@href"/>
          <xsl:with-param name="extension" select="$OUTEXT"/>
          <xsl:with-param name="ignore-fragment" select="true()"/>
        </xsl:call-template>
        <xsl:if test="contains(@href, '#')">
          <xsl:text>#</xsl:text>
          <xsl:value-of select="dita-ot:generate-id(dita-ot:get-topic-id(@href), dita-ot:get-element-id(@href))"/>
        </xsl:if>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates select="." mode="ditamsg:unknown-extension"/>
        <xsl:value-of select="@href"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!--breadcrumb template: next, prev-->
  <xsl:template match="*[contains(@class, ' topic/link ')][@role = ('next', 'previous')]" mode="breadcrumb">
    <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
    <a>
      <xsl:call-template name="commonattributes"/>
      <xsl:apply-templates select="." mode="add-linking-attributes"/>
      <xsl:apply-templates select="." mode="add-title-as-hoverhelp"/>

      <!-- Allow for unknown metadata (future-proofing) -->
      <xsl:apply-templates select="*[contains(@class, ' topic/data ') or contains(@class, ' topic/foreign ')]"/>

      <!--use string as output link text for now, use image eventually-->
      <xsl:choose>
        <xsl:when test="@role = 'next'">
          <xsl:call-template name="getVariable">
            <xsl:with-param name="id" select="'Next topic'"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:when test="@role = 'previous'">
          <xsl:call-template name="getVariable">
            <xsl:with-param name="id" select="'Previous topic'"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:otherwise><!--both role values tested - no otherwise--></xsl:otherwise>
      </xsl:choose>
    </a>
    <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  </xsl:template>

  <!--prereq template-->

  <xsl:template mode="prereqs" match="*[contains(@class, ' topic/link ')]" priority="2">
    <dd>
      <!-- Allow for unknown metadata (future-proofing) -->
      <xsl:apply-templates select="*[contains(@class, ' topic/data ') or contains(@class, ' topic/foreign ')]"/>
      <xsl:call-template name="makelink"/>
    </dd>
    <xsl:value-of select="$newline"/>
  </xsl:template>

  <!--plain templates: next, prev, ancestor/parent, children, everything else-->

  <xsl:template name="nextlink" match="*[contains(@class, ' topic/link ')][@role = 'next']" priority="2">
    <strong>
      <!-- Allow for unknown metadata (future-proofing) -->
      <xsl:apply-templates select="*[contains(@class, ' topic/data ') or contains(@class, ' topic/foreign ')]"/>
      <xsl:call-template name="getVariable">
        <xsl:with-param name="id" select="'Next topic'"/>
      </xsl:call-template>
      <xsl:call-template name="getVariable">
        <xsl:with-param name="id" select="'ColonSymbol'"/>
      </xsl:call-template>
    </strong>
    <xsl:text> </xsl:text>
    <xsl:call-template name="makelink"/>
  </xsl:template>

  <xsl:template name="prevlink" match="*[contains(@class, ' topic/link ')][@role = 'previous']" priority="2">
    <strong>
      <!-- Allow for unknown metadata (future-proofing) -->
      <xsl:apply-templates select="*[contains(@class, ' topic/data ') or contains(@class, ' topic/foreign ')]"/>
      <xsl:call-template name="getVariable">
        <xsl:with-param name="id" select="'Previous topic'"/>
      </xsl:call-template>
      <xsl:call-template name="getVariable">
        <xsl:with-param name="id" select="'ColonSymbol'"/>
      </xsl:call-template>
    </strong>
    <xsl:text> </xsl:text>
    <xsl:call-template name="makelink"/>
  </xsl:template>

  <xsl:template name="parentlink" match="*[contains(@class, ' topic/link ')][@role = 'parent']" priority="2">
    <strong>
      <!-- Allow for unknown metadata (future-proofing) -->
      <xsl:apply-templates select="*[contains(@class, ' topic/data ') or contains(@class, ' topic/foreign ')]"/>
      <xsl:call-template name="getVariable">
        <xsl:with-param name="id" select="'Parent topic'"/>
      </xsl:call-template>
      <xsl:call-template name="getVariable">
        <xsl:with-param name="id" select="'ColonSymbol'"/>
      </xsl:call-template>
    </strong>
    <xsl:text> </xsl:text>
    <xsl:call-template name="makelink"/>
  </xsl:template>

  <!--basic child processing-->
  <xsl:template match="*[contains(@class, ' topic/link ')][@role = ('child', 'descendant')]" priority="2" name="topic.link_child">
    <li class="ulchildlink">
      <xsl:call-template name="commonattributes">
        <xsl:with-param name="default-output-class" select="'ulchildlink'"/>
      </xsl:call-template>
      <!-- Allow for unknown metadata (future-proofing) -->
      <xsl:apply-templates select="*[contains(@class, ' topic/data ') or contains(@class, ' topic/foreign ')]"/>
      <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
      <strong>
        <xsl:apply-templates select="." mode="related-links:unordered.child.prefix"/>
        <xsl:apply-templates select="." mode="add-link-highlight-at-start"/>
        <a>
          <xsl:apply-templates select="." mode="add-linking-attributes"/>
          <xsl:apply-templates select="." mode="add-hoverhelp-to-child-links"/>

          <!--use linktext as linktext if it exists, otherwise use href as linktext-->
          <xsl:choose>
            <xsl:when test="*[contains(@class, ' topic/linktext ')]">
              <xsl:apply-templates select="*[contains(@class, ' topic/linktext ')]"/>
            </xsl:when>
            <xsl:otherwise>
              <!--use href-->
              <xsl:call-template name="href"/>
            </xsl:otherwise>
          </xsl:choose>
        </a>
        <xsl:apply-templates select="." mode="add-link-highlight-at-end"/>
      </strong>
      <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
      <br/>
      <xsl:value-of select="$newline"/>
      <!--add the description on the next line, like a summary-->
      <xsl:apply-templates select="*[contains(@class, ' topic/desc ')]"/>
    </li>
    <xsl:value-of select="$newline"/>
  </xsl:template>

  <!--ordered child processing-->
  <xsl:template match="*[@collection-type = 'sequence']/*[contains(@class, ' topic/link ')][@role = ('child', 'descendant')]" priority="3" name="topic.link_orderedchild">
    <li class="olchildlink">
      <xsl:call-template name="commonattributes">
        <xsl:with-param name="default-output-class" select="'olchildlink'"/>
      </xsl:call-template>
      <!-- Allow for unknown metadata (future-proofing) -->
      <xsl:apply-templates select="*[contains(@class, ' topic/data ') or contains(@class, ' topic/foreign ')]"/>
      <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
      <xsl:apply-templates select="." mode="related-links:ordered.child.prefix"/>
      <xsl:apply-templates select="." mode="add-link-highlight-at-start"/>
      <a>
        <xsl:apply-templates select="." mode="add-linking-attributes"/>
        <xsl:apply-templates select="." mode="add-hoverhelp-to-child-links"/>

        <!--use linktext as linktext if it exists, otherwise use href as linktext-->
        <xsl:choose>
          <xsl:when test="*[contains(@class, ' topic/linktext ')]">
            <xsl:apply-templates select="*[contains(@class, ' topic/linktext ')]"/>
          </xsl:when>
          <xsl:otherwise>
            <!--use href-->
            <xsl:call-template name="href"/>
          </xsl:otherwise>
        </xsl:choose>
      </a>
      <xsl:apply-templates select="." mode="add-link-highlight-at-end"/>
      <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
      <br/>
      <xsl:value-of select="$newline"/>
      <!--add the description on a new line, unlike an info, to avoid issues with punctuation (adding a period)-->
      <xsl:apply-templates select="*[contains(@class, ' topic/desc ')]"/>
    </li>
    <xsl:value-of select="$newline"/>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/link ')]" name="topic.link">
    <xsl:if test="(@role and $include.roles = @role) or
                  (empty(@role) and $include.roles = '#default')">
      <xsl:choose>
        <!-- Linklist links put out <br/> in "processlinklist" -->
        <xsl:when test="ancestor::*[contains(@class, ' topic/linklist ')]">
          <li class="linklist"><xsl:call-template name="makelink"/></li>
        </xsl:when>
        <!-- Ancestor links go in the breadcrumb trail, and should not get a <br/> -->
        <xsl:when test="@role = 'ancestor'">
          <xsl:call-template name="makelink"/>
        </xsl:when>
        <!-- Items with these roles should always go to output, and are not included in the hideduplicates key. -->
        <xsl:when test="@role and not(@role = ('cousin', 'external', 'friend', 'other', 'sample', 'sibling'))">
          <div>
            <xsl:call-template name="makelink"/>
          </div>
          <xsl:value-of select="$newline"/>
        </xsl:when>
        <!-- If roles do not match, but nearly everything else does, skip the link. -->
        <xsl:when test="key('hideduplicates', related-links:hideduplicates(.))[2]">
          <xsl:choose>
            <xsl:when test="generate-id(.) = generate-id(key('hideduplicates', related-links:hideduplicates(.))[1])">
              <div>
                <xsl:call-template name="makelink"/>
              </div>
              <xsl:value-of select="$newline"/>
            </xsl:when>
            <!-- If this is filtered out, we may need the duplicate link message anyway. -->
            <xsl:otherwise>
              <xsl:call-template name="linkdupinfo"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:when>
        <xsl:otherwise>
          <div>
            <xsl:call-template name="makelink"/>
          </div>
          <xsl:value-of select="$newline"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:if>
  </xsl:template>
  
  <!--creating the actual link-->
  <xsl:template name="makelink">
    <xsl:call-template name="linkdupinfo"/>
    <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
    <xsl:apply-templates select="." mode="add-link-highlight-at-start"/>
    <a>
      <xsl:call-template name="commonattributes"/>
      <xsl:apply-templates select="." mode="add-linking-attributes"/>
      <xsl:apply-templates select="." mode="add-desc-as-hoverhelp"/>
      <!-- Allow for unknown metadata (future-proofing) -->
      <xsl:apply-templates select="*[contains(@class, ' topic/data ') or contains(@class, ' topic/foreign ')]"/>
      <!--use linktext as linktext if it exists, otherwise use href as linktext-->
      <xsl:choose>
        <xsl:when test="*[contains(@class, ' topic/linktext ')]">
          <xsl:apply-templates select="*[contains(@class, ' topic/linktext ')]"/>
        </xsl:when>
        <xsl:otherwise>
          <!--use href-->
          <xsl:call-template name="href"/>
        </xsl:otherwise>
      </xsl:choose>
    </a>
    <xsl:apply-templates select="." mode="add-link-highlight-at-end"/>
    <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  </xsl:template>

  <!--process linktext elements by explicitly ignoring them and applying templates to their content; otherwise flagged as unprocessed content by the dit2htm transform-->
  <xsl:template match="*[contains(@class, ' topic/linktext ')]" name="topic.linktext">
    <xsl:apply-templates select="* | text()"/>
  </xsl:template>

  <!--process link desc by explicitly ignoring them and applying templates to their content; otherwise flagged as unprocessed content by the dit2htm transform-->
  <xsl:template match="*[contains(@class, ' topic/link ')]/*[contains(@class, ' topic/desc ')]" name="topic.link_desc">
    <xsl:apply-templates select="* | text()"/>
  </xsl:template>

  <!--linklists-->
  <xsl:template match="*[contains(@class, ' topic/linklist ')]/@xml:lang" priority="100">
    <xsl:if test="(empty(parent::*/ancestor::*[@xml:lang][1]/@xml:lang) and .!=$DEFAULTLANG) or
      .!=parent::*/ancestor::*[@xml:lang][1]/@xml:lang">
      <xsl:next-match/>
    </xsl:if>
  </xsl:template>
  <xsl:template match="*[contains(@class, ' topic/linklist ')]" name="topic.linklist">
    <xsl:value-of select="$newline"/>
    <xsl:choose>
      <!-- if this is a first-level linklist with no child links in it, put it in a div (flush left)-->
      <xsl:when test="(empty(parent::*) or parent::*[contains(@class, ' topic/related-links ')])
                      and not(child::*[contains(@class, ' topic/link ')][@role = ('child', 'descendant')])">
        <div class="linklist">
          <xsl:apply-templates select="." mode="processlinklist"/>
        </div>
      </xsl:when>
      <!-- When it contains children, indent with child class -->
      <xsl:when test="child::*[contains(@class, ' topic/link ')][@role = ('child', 'descendant')]">
        <div class="linklistwithchild">
          <xsl:apply-templates select="." mode="processlinklist">
            <xsl:with-param name="default-list-type" select="'linklistwithchild'"/>
          </xsl:apply-templates>
        </div>
      </xsl:when>
      <!-- It is a nested linklist, indent with other class -->
      <xsl:otherwise>
        <div class="sublinklist">
          <xsl:apply-templates select="." mode="processlinklist">
            <xsl:with-param name="default-list-type" select="'sublinklist'"/>
          </xsl:apply-templates>
        </div>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:value-of select="$newline"/>
  </xsl:template>

  <xsl:template match="*" mode="processlinklist">
    <xsl:param name="default-list-type" select="'linklist'" as="xs:string"/>
    <xsl:call-template name="commonattributes">
      <xsl:with-param name="default-output-class" select="$default-list-type"/>
    </xsl:call-template>
    <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
    <xsl:apply-templates select="*[contains(@class, ' topic/title ')]"/>
    <xsl:apply-templates select="*[contains(@class, ' topic/desc ')]"/>
    <xsl:if test="exists(*[contains(@class, ' topic/linklist ')] | *[contains(@class, ' topic/link ')])">
      <ul class="linklist">
        <xsl:for-each select="*[contains(@class, ' topic/linklist ')] | *[contains(@class, ' topic/link ')]">
          <xsl:choose>
            <!-- for children, li wrapper is created in main template -->
            <xsl:when test="contains(@class, ' topic/link ') and (@role = ('child', 'descendant'))">
              <xsl:value-of select="$newline"/>
              <xsl:apply-templates select="."/>
            </xsl:when>
            <xsl:when test="contains(@class, ' topic/link ')">
              <xsl:value-of select="$newline"/>
              <xsl:apply-templates select="."/>
            </xsl:when>
            <xsl:otherwise><!-- nested linklist -->
              <xsl:value-of select="$newline"/>
              <li class="sublinklist"><xsl:apply-templates select="."/></li>
            </xsl:otherwise>
          </xsl:choose>
          </xsl:for-each>
        </ul>
    </xsl:if>
    <xsl:apply-templates select="*[contains(@class, ' topic/linkinfo ')]"/>
    <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/linkinfo ')]" name="topic.linkinfo">
    <xsl:apply-templates/>
    <br/>
    <xsl:value-of select="$newline"/>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/linklist ')]/*[contains(@class, ' topic/title ')]" name="topic.linklist_title">
    <strong>
      <xsl:apply-templates/>
    </strong>
    <br/>
    <xsl:value-of select="$newline"/>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/linklist ')]/*[contains(@class, ' topic/desc ')]" name="topic.linklist_desc">
    <xsl:apply-templates/>
    <br/>
    <xsl:value-of select="$newline"/>
  </xsl:template>

  <xsl:template name="linkdupinfo">
    <!-- Skip duplicate test for generated links -->
    <xsl:if test="ancestor::*[contains(@class, ' topic/related-links ')]">
      <xsl:variable name="linkdup" select="key('linkdup', concat(ancestor::*[contains(@class, ' topic/related-links ')]/parent::*[contains(@class, ' topic/topic ')]/@id, ' ', @href))"/>
      <!-- has duplicate links and this is the first occurrance -->
      <xsl:if test="$linkdup[2] and generate-id(.) = generate-id($linkdup[1])">
        <!-- If the link is exactly the same, do not output message. The duplicate will automatically be removed. -->
        <xsl:if test="not(key('link', related-links:link(.))[2])">
          <xsl:apply-templates select="." mode="ditamsg:link-may-be-duplicate"/>
        </xsl:if>
      </xsl:if>
    </xsl:if>
  </xsl:template>

  <!-- Match an xref or link and add hover help.
     Normal treatment: if desc is present and not empty, create hovertext.
     Using title (for next/previous links, etc): always create, use title or target. -->
  <xsl:template match="*" mode="add-desc-as-hoverhelp">
    <xsl:param name="hovertext"/>
    <xsl:variable name="h">
      <xsl:choose>
        <xsl:when test="normalize-space($hovertext)">
          <xsl:value-of select="$hovertext"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates select="*[contains(@class, ' topic/desc ')][1]" mode="text-only"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:if test="normalize-space($h)">
      <xsl:attribute name="title" select="normalize-space($h)"/>
    </xsl:if>
  </xsl:template>
  <xsl:template match="*" mode="add-title-as-hoverhelp">
    <!--use link element's linktext as hoverhelp-->
    <xsl:attribute name="title">
      <xsl:choose>
        <xsl:when test="*[contains(@class, ' topic/linktext ')]">
          <xsl:value-of select="normalize-space(*[contains(@class, ' topic/linktext ')])"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:call-template name="href"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:attribute>
  </xsl:template>
  <xsl:template match="*" mode="add-hoverhelp-to-child-links">
    <!-- By default, desc comes out inline, so no hover help is added.
       Can override this template to add hover help to child links. -->
  </xsl:template>

  <!-- When converting to mode template, move commonattributes out;
     this template is dedicated to linking based attributes, and
     allows the common linking set to be used when commonattributes
     already exists for an ancestor. -->
  <xsl:template match="*" mode="add-linking-attributes">
    <xsl:apply-templates select="." mode="add-href-attribute"/>
    <xsl:apply-templates select="." mode="add-link-target-attribute"/>
    <xsl:apply-templates select="." mode="add-custom-link-attributes"/>
  </xsl:template>

  <xsl:template match="*" mode="add-href-attribute">
    <xsl:if test="@href and normalize-space(@href)">
      <xsl:attribute name="href">
        <xsl:apply-templates select="." mode="determine-final-href"/>
      </xsl:attribute>
    </xsl:if>
  </xsl:template>

  <xsl:template match="*" mode="add-link-target-attribute">
    <xsl:if test="@scope = 'external' or @type = 'external' or ((lower-case(@format) = 'pdf') and not(@scope = 'local'))">
      <xsl:attribute name="target">_blank</xsl:attribute>
    </xsl:if>
  </xsl:template>

  <xsl:template match="*" mode="ditamsg:link-may-be-duplicate">
    <xsl:param name="href" select="@href" as="xs:string"/>
    <xsl:param name="outfile" as="xs:string">
      <xsl:call-template name="replace-extension">
        <xsl:with-param name="filename" select="$FILENAME"/>
        <xsl:with-param name="extension" select="$OUTEXT"/>
        <xsl:with-param name="ignore-fragment" select="true()"/>
      </xsl:call-template>
    </xsl:param>
    <xsl:call-template name="output-message">
      <xsl:with-param name="id" select="'DOTX043I'"/>
      <xsl:with-param name="msgparams">%1=<xsl:value-of select="$href"/>;%2=<xsl:value-of select="$outfile"/></xsl:with-param>
    </xsl:call-template>
  </xsl:template>

</xsl:stylesheet>
