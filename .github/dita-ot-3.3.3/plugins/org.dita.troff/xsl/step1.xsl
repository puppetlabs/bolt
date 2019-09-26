<?xml version="1.0" encoding="UTF-8" ?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2004, 2006 IBM Corporation

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet version="2.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:related-links="http:// dita-ot.sourceforge.net/ns/200709/related-links"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                exclude-result-prefixes="related-links xs"
                >

<!--
   ALL ELEMENTS CAN TAKE @xtrf, @xtrc, @xml:lang
   
   Attributes on dita: 
   
   Attributes on section: 

   Attributes on sectiontitle: 
   
   Attributes on block:
      @xml:space="preserve"
      @position="center"
      @expanse="column|page" - column is default, page means ignore any indent
      @indent="digit" - additional indent new for this element
      @compact="yes|no"
      @leadin="" - text that appears once at the start of the element. It does not get the
                   extra indenting specified by @indent.
                   
   Attributes on text:
      @style="bold|italics|underlined|tt|sup|sub"
      @href="" [target, if this is a link]
      @format="" copy through @format for a link
      @scope="" copy through @scope for a link
-->

<xsl:import href="plugin:org.dita.base:xsl/common/output-message.xsl"/>
<xsl:import href="plugin:org.dita.base:xsl/common/dita-utilities.xsl"/>
<xsl:import href="plugin:org.dita.base:xsl/common/related-links.xsl"/>
<xsl:import href="rel-links.xsl"/>

<xsl:output method="xml"
            encoding="UTF-8"
            indent="no"
/>

<xsl:param name="FILENAME"></xsl:param> <!-- Needed by rel-links -->
<xsl:param name="DRAFT">no</xsl:param>  <!-- Include draft information? 'no' or 'yes' -->
<!-- Deprecated since 2.3 -->
<xsl:variable name="msgprefix">DOTX</xsl:variable> <!-- Prefix for messages -->
<xsl:variable name="OUTEXT"></xsl:variable>  <!-- extension will go at the end of links -->
<xsl:variable name="newline"><xsl:text>
</xsl:text></xsl:variable>

<!-- Copy debug attributes to the elements we are creating -->
<xsl:template name="debug"><xsl:apply-templates select="@xtrf|@xtrc"/></xsl:template>
<xsl:template match="@xtrf|@xtrc">
  <xsl:copy/>
</xsl:template>

<!-- Copy attributes that can appear on any element in the intermediate syntax -->
<xsl:template name="commonatts">
  <xsl:call-template name="debug"/>
  <xsl:apply-templates select="@xml:lang"/>
</xsl:template>
<xsl:template match="@xml:lang">
  <xsl:copy/>
</xsl:template>

<!-- Root rule. Intermediate format will always have a <dita> wrapper. -->
<xsl:template match="/">
  <xsl:variable name="lowerLang">
    <xsl:for-each select="*[1]"><xsl:call-template name="getLowerCaseLang"/></xsl:for-each>
  </xsl:variable>
  <xsl:variable name="dir">
    <xsl:choose>
      <xsl:when test="$lowerLang='he' or $lowerLang='he-il' or $lowerLang='ar' or $lowerLang='ar-eg'">rtl</xsl:when>
      <xsl:otherwise>ltr</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <dita dir="{$dir}">
    <xsl:apply-templates/>
    <xsl:apply-templates select="//*[contains(@class,' topic/fn ')]" mode="endnotes"/>
  </dita>
</xsl:template>

<!-- Place the topic in a block. No indenting needed for topic. -->
<xsl:template match="*[contains(@class,' topic/topic ')]">
    <xsl:choose>
        <xsl:when test="parent::*[contains(@class,' topic/topic ')]">
          <block><xsl:call-template name="commonatts"/><xsl:apply-templates/></block>
        </xsl:when>
        <xsl:when test="parent::dita and preceding-sibling::*">
            <block><xsl:call-template name="commonatts"/><xsl:apply-templates/></block>
        </xsl:when>
        <xsl:otherwise>
            <!-- First topic in the file. Call debug: attributes go on <dita>. -->
            <xsl:call-template name="commonatts"/>
            <xsl:apply-templates/>
        </xsl:otherwise>
    </xsl:choose>
</xsl:template>

<!-- Place the topic's title in a block for centering -->
<xsl:template match="*[contains(@class,' topic/topic ')]/*[contains(@class,' topic/title ')]">
    <block position="center"><xsl:call-template name="commonatts"/>
      <text style="bold"><xsl:call-template name="commonatts"/><xsl:apply-templates/></text>
    </block>
    <xsl:apply-templates select="." mode="check-for-prereq"/>
</xsl:template>

<!-- These block elements do not get special formatting (though the children may);
     drop them into a block element. -->
<xsl:template match="*[contains(@class,' topic/p ')] |
                     *[contains(@class,' topic/shortdesc ')] |
                     *[contains(@class,' topic/fig ')]">
    <!-- save frame on figure? -->
  <block><xsl:call-template name="commonatts"/><xsl:apply-templates/></block>
  <xsl:if test="contains(@class,' topic/shortdesc ')">
    <xsl:apply-templates select="." mode="check-for-prereq"/>
  </xsl:if>
</xsl:template>

<!-- These titles should come out as bold -->
<xsl:template match="*[contains(@class,' topic/fig ')]/*[contains(@class,' topic/title ')]">
  <xsl:variable name="fignum" select="count(preceding::*[contains(@class,' topic/fig ')]) + 1" as="xs:integer"/>
  <block><xsl:call-template name="commonatts"/>
    <text style="bold">
      <xsl:call-template name="getVariable"><xsl:with-param name="id" select="'Figure'"/></xsl:call-template>
      <xsl:text> </xsl:text><xsl:value-of select="$fignum"/>. <xsl:text/>
      <xsl:apply-templates/>
    </text>
  </block>
</xsl:template>
<xsl:template match="*[contains(@class,' topic/linklist ')]/*[contains(@class,' topic/title ')]">
  <block><xsl:call-template name="commonatts"/>
    <text style="bold"><xsl:apply-templates/></text>
  </block>
</xsl:template>


<!-- Sections and examples format the same today, so put them into a section element.
     This is used to distinguish sections, usually with titles, which can get special 
     formatting as such in output formats like troff. -->
<xsl:template match="*[contains(@class,' topic/section ')] | *[contains(@class,' topic/example ')]">
  <section><xsl:call-template name="commonatts"/>
    <!-- Ensure the title comes first -->
    <xsl:apply-templates select="*[contains(@class,' topic/title ')]"/>
    <xsl:apply-templates select="text()|*[not(contains(@class,' topic/title '))]"/>
  </section>
</xsl:template>
<!-- Match section or example titles -->
<xsl:template match="*[contains(@class,' topic/section ') or contains(@class,' topic/example ')]/*[contains(@class,' topic/title ')]">
  <sectiontitle><xsl:call-template name="commonatts"/><xsl:apply-templates/></sectiontitle>
</xsl:template>

<!-- If needed, these can be broken apart to indicate that pre uses monospace. Could do this
     by adding @style to the block. -->
<xsl:template match="*[contains(@class,' topic/pre ')] |
                     *[contains(@class,' topic/lines ')]">
    <block xml:space="preserve"><xsl:call-template name="commonatts"/><xsl:apply-templates/></block>
</xsl:template>

<!-- Indent lq 6 spaces, and treat as any other block. -->
<xsl:template match="*[contains(@class,' topic/lq ')]">
    <block indent="6">
      <xsl:call-template name="commonatts"/>
      <xsl:apply-templates/>
      <xsl:if test="@reftitle"><text style="italics"><xsl:text> </xsl:text><xsl:value-of select="@reftitle"/></text></xsl:if>
      <xsl:if test="@href"><text> [<xsl:value-of select="@href"/>]</text></xsl:if>
    </block>
</xsl:template>

<!-- Deterimne the title and place it in a bold text element. Currently all note types
     format the same. In some cases it may be desireable to place the contents into
     an additional <block> to set them apart from the note title. -->
<xsl:template match="*[contains(@class,' topic/note ')]">
    <xsl:variable name="noteText">
        <xsl:choose>
            <xsl:when test="not(@type) or @type='note'">
                <xsl:call-template name="getVariable"><xsl:with-param name="id" select="'Note'"/></xsl:call-template>
            </xsl:when>
            <xsl:when test="@type='attention'">
                <xsl:call-template name="getVariable"><xsl:with-param name="id" select="'Attention'"/></xsl:call-template>
            </xsl:when>
            <xsl:when test="@type='caution'">
                <xsl:call-template name="getVariable"><xsl:with-param name="id" select="'Caution'"/></xsl:call-template>
            </xsl:when>
            <xsl:when test="@type='danger'">
                <xsl:call-template name="getVariable"><xsl:with-param name="id" select="'Danger'"/></xsl:call-template>
            </xsl:when>
            <xsl:when test="@type='fastpath'">
                <xsl:call-template name="getVariable"><xsl:with-param name="id" select="'Fastpath'"/></xsl:call-template>
            </xsl:when>
            <xsl:when test="@type='important'">
                <xsl:call-template name="getVariable"><xsl:with-param name="id" select="'Important'"/></xsl:call-template>
            </xsl:when>
            <xsl:when test="@type='remember'">
                <xsl:call-template name="getVariable"><xsl:with-param name="id" select="'Remember'"/></xsl:call-template>
            </xsl:when>
            <xsl:when test="@type='restriction'">
                <xsl:call-template name="getVariable"><xsl:with-param name="id" select="'Restriction'"/></xsl:call-template>
            </xsl:when>
            <xsl:when test="@type='tip'">
                <xsl:call-template name="getVariable"><xsl:with-param name="id" select="'Tip'"/></xsl:call-template>
            </xsl:when>
            <xsl:when test="@type='trouble'">
              <xsl:call-template name="getVariable"><xsl:with-param name="id" select="'Trouble'"/></xsl:call-template>
            </xsl:when>
            <xsl:when test="@type='other' and @othertype">
                <xsl:value-of select="@othertype"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:call-template name="getVariable"><xsl:with-param name="id" select="'Note'"/></xsl:call-template>
            </xsl:otherwise>
        </xsl:choose>
        <xsl:call-template name="getVariable"><xsl:with-param name="id" select="'ColonSymbol'"/></xsl:call-template>
        <xsl:text> </xsl:text>
    </xsl:variable>
    <block><xsl:call-template name="commonatts"/>
        <text style="bold"><xsl:call-template name="commonatts"/><xsl:value-of select="$noteText"/></text>
        <xsl:apply-templates/>
    </block>                                 
</xsl:template>

<!-- All lists are block elements. Store @compact information on the children. -->
<xsl:template match="*[contains(@class,' topic/ul ')] | *[contains(@class,' topic/ol ')] | *[contains(@class,' topic/sl ')]">
    <block>
        <xsl:call-template name="commonatts"/><xsl:apply-templates/>
    </block>
</xsl:template>

<!-- Simple list items do not get any lead-in text. Just indent 3 spaces for each one. -->
<xsl:template match="*[contains(@class,' topic/sli ')]">
    <block compact="yes" indent="3"><xsl:call-template name="commonatts"/><xsl:apply-templates/></block>
</xsl:template>

<!-- Ul elements always have * for lead-in text. Add 3 to indent, and store @compact. -->
<xsl:template match="*[contains(@class,' topic/ul ')]/*[contains(@class,' topic/li ')]">
    <block leadin="*  " indent="3">
        <xsl:call-template name="commonatts"/>
        <xsl:if test="parent::*[@compact='yes']">
            <xsl:attribute name="compact">yes</xsl:attribute>
        </xsl:if>
        <xsl:apply-templates/>
    </block>
</xsl:template>

<xsl:template match="*[contains(@class,' topic/itemgroup ')]" name="topic.itemgroup">
  <xsl:if test="preceding-sibling::*"><text><xsl:text> </xsl:text></text></xsl:if>
  <xsl:apply-templates/>
</xsl:template>

<!-- Get the current list number. This is a recursive function that counts elements in the
     current list, and adds that after the number from each ancestor ordered list item. 
     The list numbering uses 1.b.iii.4.e.vi formatting (decimal, alpha, Roman, ...) -->
<xsl:template match="*" mode="get-list-number">
    <xsl:variable name="depth" select="count(ancestor-or-self::*[contains(@class,' topic/li ')][contains(parent::*/@class,' topic/ol ')])"
      as="xs:integer"/>
    <xsl:apply-templates select="ancestor::*[contains(@class,' topic/li ')][contains(parent::*/@class,' topic/ol ')][1]" mode="get-list-number"/>
    <xsl:choose>
        <xsl:when test="$depth mod 3 = 0"><xsl:number count="*" format="i"/>.<xsl:text/></xsl:when>
        <xsl:when test="$depth mod 3 = 1"><xsl:number count="*"/>.<xsl:text/></xsl:when>
        <xsl:when test="$depth mod 3 = 2"><xsl:number count="*" format="a"/>.<xsl:text/></xsl:when>
    </xsl:choose>
</xsl:template>

<!-- Match an ordered list item. Must find the current list number, and use that as lead-in text.
     The indent is set to go in as far as the lead-in text. -->
<xsl:template match="*[contains(@class,' topic/ol ')]/*[contains(@class,' topic/li ')]">
    <xsl:variable name="listintro">
       <!--<xsl:number count="*"/>. <xsl:text/>-->
        <xsl:apply-templates select="." mode="get-list-number"/><xsl:text> </xsl:text>
    </xsl:variable>
    <block leadin="{$listintro}" indent="{string-length($listintro)}">
        <xsl:call-template name="commonatts"/>
        <xsl:if test="parent::*[@compact='yes']">
            <xsl:attribute name="compact">yes</xsl:attribute>
        </xsl:if>
        <xsl:apply-templates/>
    </block>
</xsl:template>

<!-- Drop dl into a block. Descendants will pick up the proper indenting/formatting. -->
<xsl:template match="*[contains(@class,' topic/dl ')]">
    <block><xsl:call-template name="commonatts"/><xsl:apply-templates/></block>
</xsl:template>

<!-- Dlentry and dlhead do not need to create additional blocks; children will get blocks. -->
<xsl:template match="*[contains(@class,' topic/dlentry ')]|*[contains(@class,' topic/dlhead ')]">
    <xsl:apply-templates/>
</xsl:template>

<!-- Terms and term headings should go into block elements. Bold the term contents -->
<xsl:template match="*[contains(@class,' topic/dt ')]|*[contains(@class,' topic/dthd ')]">
    <block><xsl:call-template name="commonatts"/>
      <!-- When there are 2 terms, do not create an extra line between them. If this is the first term,
           keep the extra space between it and the previous dlentry. -->
      <xsl:if test="preceding-sibling::*[1][contains(@class,' topic/dt ')] or
                    ../../@compact='yes'">
        <xsl:attribute name="compact">yes</xsl:attribute>
      </xsl:if>
      <text style="bold"><xsl:call-template name="commonatts"/>
        <xsl:apply-templates/>
      </text>
    </block>
</xsl:template>

<!-- Indent the definition 9 spaces. The compact=yes value ensures it will appear on the
     line after the term. May want to bold ddhd? -->
<xsl:template match="*[contains(@class,' topic/dd ')]|*[contains(@class,' topic/ddhd ')]">
    <block indent="9" compact="yes"><xsl:call-template name="commonatts"/><xsl:apply-templates/></block>
</xsl:template>

<!-- Table formatting based off of DL formatting; first column aligns to start of 'page',
     second and following columns indent -->
<xsl:template match="*[contains(@class,' topic/simpletable ') or contains(@class,' topic/table ')]">
  <block><xsl:call-template name="commonatts"/><xsl:apply-templates/></block>
</xsl:template>

<!-- strow and sthead do not need to create additional blocks; children will get blocks. -->
<xsl:template match="*[contains(@class,' topic/strow ')]|*[contains(@class,' topic/sthead ')]">
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="*[contains(@class,' topic/tgroup ') or contains(@class,' topic/thead ') or contains(@class,' topic/tbody ') or
                       contains(@class,' topic/row ')]">
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="*[contains(@class,' topic/stentry ')]">
  <xsl:choose>
    <xsl:when test="preceding-sibling::*[contains(@class,' topic/stentry ')]">
      <block indent="9" compact="no">
        <xsl:call-template name="commonatts"/>
        <xsl:choose>
          <xsl:when test="parent::*[contains(@class,' topic/sthead ')]">
            <text style="bold"><xsl:call-template name="commonatts"/><xsl:apply-templates/></text>
          </xsl:when>
          <xsl:otherwise>
            <xsl:apply-templates/>
          </xsl:otherwise>
        </xsl:choose>
      </block>
    </xsl:when>
    <xsl:otherwise>
      <block indent="3"><xsl:call-template name="commonatts"/>
        <text style="bold"><xsl:call-template name="commonatts"/>
          <xsl:apply-templates/>
        </text>
      </block>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>


<xsl:template match="*[contains(@class,' topic/entry ')]">
  <xsl:choose>
    <xsl:when test="preceding-sibling::*[contains(@class,' topic/entry ')]">
      <block indent="9" compact="no">
        <xsl:call-template name="commonatts"/>
        <xsl:choose>
          <xsl:when test="parent::*/parent::*[contains(@class,' topic/thead ')]">
            <text style="bold"><xsl:call-template name="commonatts"/><xsl:apply-templates/></text>
          </xsl:when>
          <xsl:otherwise>
            <xsl:apply-templates/>
          </xsl:otherwise>
        </xsl:choose>
      </block>
    </xsl:when>
    <xsl:otherwise>
      <block indent="3"><xsl:call-template name="commonatts"/>
        <text style="bold"><xsl:call-template name="commonatts"/>
          <xsl:apply-templates/>
        </text>
      </block>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template name="output-alt-text">
  <xsl:choose>
      <xsl:when test="*"><xsl:apply-templates/></xsl:when>
      <xsl:when test="@alt"><xsl:value-of select="@alt"/></xsl:when>
  </xsl:choose>
</xsl:template>

<!-- Images do not appear in text, so use the alternate text -->
<xsl:template match="*[contains(@class,' topic/image ')]">
    <xsl:choose>
        <xsl:when test="@placement='break'">
            <block>
              <xsl:call-template name="commonatts"/>
              <text><xsl:call-template name="commonatts"/><xsl:call-template name="output-alt-text"/></text>
            </block>
        </xsl:when>
        <xsl:otherwise>
            <text><xsl:call-template name="commonatts"/><xsl:call-template name="output-alt-text"/></text>
        </xsl:otherwise>
    </xsl:choose>
    <!-- standalone image in text, need to add newlines after -->
</xsl:template>

<!-- These are all phrase-like elements: drop them into text elements. -->
<xsl:template match="*[contains(@class,' topic/ph ')] |
                     *[contains(@class,' topic/keyword ')] |
                     *[contains(@class,' topic/term ')]">
    <text><xsl:call-template name="commonatts"/><xsl:apply-templates/></text>
</xsl:template>

<xsl:template name="output-quote">
  <xsl:text/>"<xsl:apply-templates/>"<xsl:text/>
</xsl:template>
<xsl:template match="*[contains(@class,' topic/q ')]">
    <text><xsl:call-template name="commonatts"/><xsl:call-template name="output-quote"/></text>
</xsl:template>

<xsl:template name="default-state-contents">
  <xsl:if test="@name!=name()"><xsl:value-of select="name()"/>: </xsl:if>
  <xsl:value-of select="@name"/>=<xsl:value-of select="@value"/>
</xsl:template>
<xsl:template name="default-boolean-contents">
  <xsl:value-of select="name()"/>: <xsl:value-of select="@state"/>
</xsl:template>

<xsl:template match="*[contains(@class,' topic/state ')]" name="topic.state">
  <text><xsl:call-template name="commonatts"/><xsl:call-template name="default-state-contents"/></text>
</xsl:template>
<xsl:template match="*[contains(@class,' topic/boolean ')]" name="topic.boolean">
  <text><xsl:call-template name="commonatts"/><xsl:call-template name="default-boolean-contents"/></text>
</xsl:template>

<!-- TRADEMARK PROCESSING TAKEN FROM XHTML OUTPUT, MODIFIED TO INCLUDE <text>  -->
<!-- prepare a key for each trademark tag -->
<xsl:key name="tm"  match="*[contains(@class,' topic/tm ')]" use="."/>

<!-- process the TM tag -->
<!-- removed priority 1 : should not be needed -->
<xsl:template match="*[contains(@class,' topic/tm ')]" name="topic.tm">
  <xsl:variable name="tmvalue">
    <xsl:call-template name="getTmValue"/>
  </xsl:variable>
  
  <xsl:apply-templates/> <!-- output the TM content -->

  <xsl:if test="normalize-space($tmvalue)!=''">
    <text style="sup"><xsl:value-of select="$tmvalue"/></text>
  </xsl:if>
</xsl:template>

<xsl:template name="getTmValue">
  <!-- Determine the tmclass value; IBM legal only wants some classes processed -->
  <xsl:variable name="Ltmclass" select="lower-case(@tmclass)"/>
  <!-- If this is a good class, continue... -->
  <xsl:if test="$Ltmclass='ibm' or $Ltmclass='ibmsub' or $Ltmclass='special'">
    <!-- Test for TM area's language -->
    <xsl:variable name="tmtest">
      <xsl:call-template name="tm-area"/>
    </xsl:variable>

    <!-- If this language should get trademark markers, continue... -->
    <xsl:if test="$tmtest='tm'">
      <xsl:variable name="tmvalue"><xsl:value-of select="@trademark"/></xsl:variable>

      <!-- Determine if this is in a title, and should be marked -->
      <xsl:variable name="usetitle">
        <xsl:if test="ancestor::*[contains(@class,' topic/title ')]/parent::*[contains(@class,' topic/topic ')]">
          <xsl:choose>
            <!-- Not the first one in a title -->
            <xsl:when test="generate-id(.)!=generate-id(key('tm',.)[1])">skip</xsl:when>
            <!-- First one in the topic, BUT it appears in a shortdesc or body; BUT NOT in an alt  -->
            <xsl:when test="//*[contains(@class,' topic/shortdesc ') or contains(@class,' topic/body ') or contains(@class,' topic/related-links ')]//*[contains(@class,' topic/tm ')][@trademark=$tmvalue][not(ancestor::*[contains(@class,' topic/alt ')])]">skip</xsl:when>
            <xsl:otherwise>use</xsl:otherwise>
          </xsl:choose>
        </xsl:if>
      </xsl:variable>

      <!-- Determine if this is in a body, and should be marked -->
      <xsl:variable name="usebody">
        <xsl:choose>
          <!-- If in a title or prolog, skip -->
          <xsl:when test="ancestor::*[contains(@class,' topic/title ') or contains(@class,' topic/prolog ')]/parent::*[contains(@class,' topic/topic ')]">skip</xsl:when>
          <!-- If in a alt, skip -->
          <xsl:when test="ancestor::*[contains(@class,' topic/alt ')]">skip</xsl:when>
          <!-- If first in the document, use it -->
          <xsl:when test="generate-id(.)=generate-id(key('tm',.)[1])">use</xsl:when>
          <!-- If there is another before this that is in the body or shortdesc, skip -->
          <xsl:when test="preceding::*[contains(@class,' topic/tm ')][@trademark=$tmvalue][not(ancestor::*[contains(@class,' topic/alt ')])][ancestor::*[contains(@class,' topic/body ') or contains(@class,' topic/shortdesc ') or contains(@class,' topic/related-links ')]]">skip</xsl:when>
          <!-- Otherwise, any before this must be in a title or ignored section -->
          <xsl:otherwise>use</xsl:otherwise>
        </xsl:choose>
      </xsl:variable>

      <!-- If it should be used in a title or used in the body, output your favorite TM marker based on the attributes -->
      <xsl:if test="$usetitle='use' or $usebody='use'">
        <xsl:choose>  <!-- ignore @tmtype=service or anything else -->
          <xsl:when test="@tmtype='tm'">(TM)</xsl:when>
          <xsl:when test="@tmtype='reg'">(R)</xsl:when>
          <xsl:otherwise/>
        </xsl:choose>
      </xsl:if>
    </xsl:if>
 </xsl:if>
</xsl:template>

<!-- Test for in TM area: returns "tm" when parent's @xml:lang needs a trademark language;
     Otherwise, leave blank.
     Use the TM for US English and the AP languages (Japanese, Korean, and both Chinese).
     Ignore the TM for all other languages. -->
<xsl:template name="tm-area">
 <xsl:variable name="parentlang">
  <xsl:call-template name="getLowerCaseLang"/>
 </xsl:variable>
 <xsl:choose>
  <xsl:when test="$parentlang='en-us' or $parentlang='en'">tm</xsl:when>
  <xsl:when test="$parentlang='ja-jp' or $parentlang='ja'">tm</xsl:when>
  <xsl:when test="$parentlang='ko-kr' or $parentlang='ko'">tm</xsl:when>
  <xsl:when test="$parentlang='zh-cn' or $parentlang='zh'">tm</xsl:when>
  <xsl:when test="$parentlang='zh-tw' or $parentlang='zh'">tm</xsl:when>
  <xsl:otherwise/>
 </xsl:choose>
</xsl:template>

<!-- How to put object into text? Basic processing will just use <desc> -->
<xsl:template match="*[contains(@class,' topic/object ')]">
  <block><xsl:call-template name="commonatts"/><xsl:apply-templates select="*[contains(@class,' topic/desc ')]"/></block>
</xsl:template>

<xsl:template match="*[contains(@class,' topic/prolog ')] | *[contains(@class,' topic/titlealts ')]"/>

<xsl:template match="*[contains(@class,' topic/body ')]">
    <block>
      <xsl:call-template name="commonatts"/>
      <xsl:apply-templates select="." mode="check-for-prereq"/>
      <xsl:apply-templates/>
    </block>
</xsl:template>

<!-- Only use required cleanup when $DRAFT=yes. Output a heading before, and a marker
     at the end, so that it stands out. -->
<xsl:template match="*[contains(@class,' topic/required-cleanup ')]">
  <xsl:if test="$DRAFT='yes'">
    <block>
      <xsl:call-template name="commonatts"/>
      <block><xsl:call-template name="commonatts"/>
        <text><xsl:call-template name="commonatts"/>
          <xsl:text>********* </xsl:text>
          <xsl:call-template name="getVariable"><xsl:with-param name="id" select="'Required cleanup'"/></xsl:call-template>
          <xsl:text> *********</xsl:text>
        </text>
      </block>
      <block><xsl:call-template name="commonatts"/><xsl:apply-templates/></block>
      <block><xsl:call-template name="commonatts"/><text>******************************</text></block>
    </block>
  </xsl:if>
</xsl:template>

<!-- Only use draft comment when $DRAFT=yes. Output a heading before, and a marker
     at the end, so that it stands out. -->
<xsl:template match="*[contains(@class,' topic/draft-comment ')]">
  <xsl:if test="$DRAFT='yes'">
    <block>
      <xsl:call-template name="commonatts"/>
      <block><xsl:call-template name="commonatts"/>
        <text><xsl:call-template name="commonatts"/>
          <xsl:text>********* </xsl:text>
          <xsl:call-template name="getVariable"><xsl:with-param name="id" select="'Draft comment'"/></xsl:call-template>
          <xsl:text> *********</xsl:text>
        </text>
      </block>
      <block><xsl:call-template name="commonatts"/><xsl:apply-templates/></block>
      <block><xsl:call-template name="commonatts"/><text>******************************</text></block>
    </block>
  </xsl:if>
</xsl:template>

<!-- Footnotes will put out the number inline, and put them all out at the end -->
<xsl:template match="*[contains(@class,' topic/fn ')]">
  <text style="sup"><xsl:call-template name="output-fn-reference"/></text>
</xsl:template>
<xsl:template name="output-fn-reference">
  <xsl:text>(</xsl:text>
  <xsl:choose>
    <xsl:when test="@callout"><xsl:value-of select="@callout"/></xsl:when>
    <xsl:otherwise><xsl:value-of select="count(preceding::*[contains(@class,' topic/fn ')]) + 1"/></xsl:otherwise>
  </xsl:choose>
  <xsl:text>)</xsl:text>
</xsl:template>
<xsl:template match="*[contains(@class,' topic/fn ')]" mode="endnotes">
  <block>
    <text>
      <xsl:choose>
        <xsl:when test="@callout"><xsl:value-of select="@callout"/></xsl:when>
        <xsl:otherwise><xsl:value-of select="count(preceding::*[contains(@class,' topic/fn ')]) + 1"/></xsl:otherwise>
      </xsl:choose>
      <xsl:text>. </xsl:text>
    </text>
    <xsl:apply-templates/>
  </block>
</xsl:template>

<xsl:template match="*[contains(@class,' topic/indexterm ')] | *[contains(@class,' topic/indextermref ')]"/>

<xsl:template name="CheckForPhraseSibling">
  <xsl:choose>
    <xsl:when test="parent::*[contains(@class,' topic/body ') or contains(@class,' topic/topic ')]">no</xsl:when>
    <xsl:when test="string-length(normalize-space(../text()[1]))>0">yes</xsl:when>
    <xsl:when test="following-sibling::*[contains(@class,' topic/ph ') or contains(@class,' topic/keyword ') or
                        contains(@class,' topic/q ') or contains(@class,' topic/term ') or
                        contains(@class,' topic/itemgroup ') or contains(@class,' topic/state ') or
                        contains(@class,' topic/xref ') or contains(@class,' topic/tm ')]">yes</xsl:when>
    <xsl:when test="preceding-sibling::*[contains(@class,' topic/ph ') or contains(@class,' topic/keyword ') or
                        contains(@class,' topic/q ') or contains(@class,' topic/term ') or
                        contains(@class,' topic/itemgroup ') or contains(@class,' topic/state ') or
                        contains(@class,' topic/xref ') or contains(@class,' topic/tm ')]">yes</xsl:when>
    <xsl:when test="following-sibling::*[contains(@class,' topic/image ')][not(@placement) or @placement='inline']">yes</xsl:when>
    <xsl:when test="preceding-sibling::*[contains(@class,' topic/image ')][not(@placement) or @placement='inline']">yes</xsl:when>
    <xsl:otherwise>no</xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- If the text node is empty, ignore it. Otherwise, put it in <text>. -->
<xsl:template match="text()">
    <xsl:choose>
        <xsl:when test="ancestor::*[@xml:space='preserve']"><text><xsl:value-of select="."/></text></xsl:when>
        <!-- If this string is only white-space, AND it is not between phrases, then drop it. -->
        <xsl:when test="string-length(normalize-space(.))=0">
          <xsl:variable name="siblingPhrase"><xsl:call-template name="CheckForPhraseSibling"/></xsl:variable>
          <xsl:if test="$siblingPhrase='yes'">
            <text><xsl:value-of select="."/></text>
          </xsl:if>
        </xsl:when>
        <xsl:otherwise><text><xsl:value-of select="."/></text></xsl:otherwise>
    </xsl:choose>
</xsl:template>

<!-- ******************* LINK PROCESSING ********************** -->

<!-- For XREF, just put it out as a text element. Save link info in case it can be used
     in the target format. -->
<xsl:template match="*[contains(@class,' topic/xref ')]">
  <text>
    <xsl:if test="@href"><xsl:attribute name="href"><xsl:value-of select="@href"/></xsl:attribute></xsl:if>
    <xsl:if test="@scope"><xsl:attribute name="scope"><xsl:value-of select="@scope"/></xsl:attribute></xsl:if>
    <xsl:if test="@format"><xsl:attribute name="format"><xsl:value-of select="@format"/></xsl:attribute></xsl:if>
    <xsl:choose>
      <xsl:when test="*[not(contains(@class,' topic/desc '))]|text()"><xsl:apply-templates/></xsl:when>
      <xsl:otherwise><xsl:value-of select="@href"/></xsl:otherwise>
    </xsl:choose>
  </text>
</xsl:template>
<xsl:template match="*[contains(@class,' topic/xref ')]/*[contains(@class,' topic/desc ')]"/>

<!-- This section re-uses the login in rel-links.xsl. Rel-links has all the needed
     logic for sorting, removing duplicates, etc. The downside is that it loses link
     attributes like scope and formatting.

     Related links is processed using rel-links. Each section is placed in a variable.
     The contents of the variable are then processed, and the XHTML coding is
     converted to the proper block or text intermediate format. -->
<!-- Override this template to ensure that prereq links are grouped with other links. -->
<!--<xsl:apply-templates select="." mode="related-links:group-unordered-links">
    <xsl:with-param name="nodes" select="descendant::*[contains(@class, ' topic/link ')]
      [count(. | key('omit-from-unordered-links', 1)) != count(key('omit-from-unordered-links', 1))]
      [generate-id(.)=generate-id((key('hideduplicates', concat(ancestor::*[contains(@class, ' topic/related-links ')]/parent::*[contains(@class, ' topic/topic ')]/@id, ' ',@href,@scope,@audience,@platform,@product,@otherprops,@rev,@type,normalize-space(child::*))))[1])]
      |
      descendant::*[contains(@class, ' topic/link ')]
      [@importance='required' and (not(@role) or @role='sibling' or @role='friend' or @role='cousin')]
      [generate-id(.)=generate-id((key('hideduplicates', concat(ancestor::*[contains(@class, ' topic/related-links ')]/parent::*[contains(@class, ' topic/topic ')]/@id, ' ',@href,@scope,@audience,@platform,@product,@otherprops,@rev,@type,normalize-space(child::*))))[1])]"/>
</xsl:apply-templates>  -->

<xsl:template match="*" mode="check-for-prereq">
  <xsl:if test="following-sibling::*[1][contains(@class,' topic/related-links ')]">
    <xsl:variable name="prereqs">
      <xsl:apply-templates select="following-sibling::*[1][contains(@class,' topic/related-links ')]" mode="prereqs"/>
    </xsl:variable>
      <xsl:apply-templates select="$prereqs" mode="reformat-links"/>
  </xsl:if>
</xsl:template>

<xsl:template match="*[contains(@class,' topic/related-links ')]">
  <xsl:variable name="ul-children">
    <xsl:call-template name="ul-child-links"/><!--handle child/descendants outside of linklists in collection-type=unordered or choice-->
  </xsl:variable>
  <xsl:variable name="ol-children">
    <xsl:call-template name="ol-child-links"/><!--handle child/descendants outside of linklists in collection-type=ordered/sequence-->
  </xsl:variable>
  <xsl:variable name="next-previous-parent">
    <xsl:call-template name="next-prev-parent-links"/><!--handle next and previous links-->
  </xsl:variable>
  <xsl:variable name="relcon">
    <xsl:call-template name="concept-links"/><!--sort remaining concept links by type-->
  </xsl:variable>
  <xsl:variable name="reltask">
    <xsl:call-template name="task-links"/><!--sort remaining task links by type-->
  </xsl:variable>
  <xsl:variable name="relref">
    <xsl:call-template name="reference-links"/><!--sort remaining reference links by type-->
  </xsl:variable>
  <xsl:variable name="relinfo">
    <xsl:call-template name="relinfo-links"/><!--handle remaining untyped and unknown-type links-->
  </xsl:variable>
  <xsl:variable name="linklists">
    <xsl:apply-templates select="*[contains(@class,' topic/linklist ')]"/>
  </xsl:variable>

  <block>
    <xsl:call-template name="commonatts"/>
    <xsl:apply-templates select="$ul-children" mode="reformat-links"/>
    <xsl:apply-templates select="$ol-children" mode="reformat-links"/>
    <xsl:apply-templates select="$next-previous-parent" mode="reformat-links"/>
    <xsl:apply-templates select="$relcon" mode="reformat-links"/>
    <xsl:apply-templates select="$reltask" mode="reformat-links"/>
    <xsl:apply-templates select="$relref" mode="reformat-links"/>
    <xsl:apply-templates select="$relinfo" mode="reformat-links"/>
    <xsl:apply-templates select="$linklists" mode="reformat-links"/>
  </block>
</xsl:template>

<xsl:template match="ul[@class='ullinks']" mode="reformat-links">
  <xsl:apply-templates mode="reformat-links"/>
</xsl:template>

<!-- Unordered child links each come out as indented blocks -->
<xsl:template match="li[@class='ulchildlink']|div[@class='ulchildlink']" mode="reformat-links">
  <block indent="3">
    <block compact="yes"><xsl:apply-templates select="strong/a/*" mode="reformat-links"/></block>
    <block compact="yes"><xsl:apply-templates select="strong/following-sibling::*" mode="reformat-links"/></block>
  </block>
</xsl:template>

<xsl:template match="ol" mode="reformat-links">
  <block><xsl:apply-templates mode="reformat-links"/></block>
</xsl:template>

<!-- Ordered child links must be numbered. The xsl:number test is fine because every item
     at this point is actually in an <li> element. -->
<xsl:template match="li[@class='olchildlink']|div[@class='olchildlink']" mode="reformat-links">
    <xsl:variable name="listintro">
        <xsl:number count="*"/>. <xsl:text/>
    </xsl:variable>
    <block>
        <block compact="yes">
            <text><xsl:value-of select="$listintro"/></text>
            <xsl:apply-templates select="br/preceding-sibling::*" mode="reformat-links"/>
        </block>
        <block compact="yes" indent="3">
            <xsl:apply-templates select="br/following-sibling::*" mode="reformat-links"/>
        </block>
    </block>
</xsl:template>

<!-- If the related concepts/tasks/ref/info sections exist, put them in blocks -->
<xsl:template match="div[@class='relconcepts' or @class='reltasks' or @class='relref' or @class='relinfo']" mode="reformat-links">
    <xsl:if test="div">
        <block>
            <block compact="yes"><xsl:apply-templates select="strong" mode="reformat-links"/></block>
            <xsl:apply-templates select="div" mode="reformat-links"/>
        </block>
    </xsl:if>
</xsl:template>

<!-- If there is anything in the familylinks div, put it in a block -->
<xsl:template match="div[@class='familylinks']" mode="reformat-links">
    <xsl:if test="div">
        <block><xsl:apply-templates mode="reformat-links"/></block>
    </xsl:if>
</xsl:template>

<!-- Parent/next/previous links get the bold intro text, and go in a block. Use
     compact=yes so that there is not extra space between these links. -->
<xsl:template match="div[@class='parentlink' or @class='previouslink' or @class='nextlink']" mode="reformat-links">
    <block compact="yes">
        <text>
            <xsl:value-of select="strong"/>
            <xsl:text> </xsl:text>
            <xsl:apply-templates select="strong/following-sibling::*" mode="reformat-links"/>
        </text>
    </block>
</xsl:template>

<!-- linklist still needs work -->
<xsl:template match="div[@class='linklist' or @class='linklistwithchild']" mode="reformat-links">
    <block><xsl:apply-templates mode="reformat-links"/></block>
</xsl:template>
<xsl:template match="div[@class='sublinklist']" mode="reformat-links">
    <block indent="3"><xsl:apply-templates mode="reformat-links"/></block>
</xsl:template>

<xsl:template match="div[@class='linklist' or @class='linklistwithchild' or @class='sublinklist']/strong" mode="reformat-links">
    <block compact="yes"><text style="bold"><xsl:apply-templates mode="reformat-links"/></text></block>
</xsl:template>

<xsl:template match="div" mode="reformat-links">
    <block compact="yes"><xsl:apply-templates mode="reformat-links"/></block>
</xsl:template>

<xsl:template match="dl[contains(@class,'prereqlinks')]" mode="reformat-links">
  <block compact="yes"><xsl:apply-templates mode="reformat-links"/></block>
</xsl:template>
<xsl:template match="dt[contains(@class,'prereq')]" mode="reformat-links">
    <block compact="yes">
      <text style="bold">
        <xsl:apply-templates mode="reformat-links"/>
      </text>
    </block>
</xsl:template>
<xsl:template match="dl[contains(@class,'prereqlinks')]/dd" mode="reformat-links">
  <block indent="9" compact="yes"><xsl:apply-templates mode="reformat-links"/></block>
</xsl:template>

<!-- If something already fell through to the ordinary processor, copy it as-is -->
<xsl:template match="text|block" mode="reformat-links">
    <xsl:copy><xsl:copy-of select="@*|*|text()"/></xsl:copy>
</xsl:template>

<xsl:template match="*" mode="reformat-links">
    <xsl:apply-templates mode="reformat-links"/>
</xsl:template>
<xsl:template match="@*" mode="reformat-links">
  <xsl:copy><xsl:value-of select="."/></xsl:copy>
</xsl:template>

<xsl:template match="strong" mode="reformat-links">
  <text style="bold"><xsl:apply-templates mode="reformat-links"/></text>
</xsl:template>

<xsl:template match="em" mode="reformat-links">
  <text style="italics"><xsl:apply-templates mode="reformat-links"/></text>
</xsl:template>

<xsl:template match="text()" mode="reformat-links">
    <xsl:choose>
        <xsl:when test="string-length(normalize-space(.))=0"/>
        <xsl:otherwise><text><xsl:value-of select="."/></text></xsl:otherwise>
    </xsl:choose>
</xsl:template>


<!--<xsl:template match="*[contains(@class,' topic/linklist ')]">
    <block><xsl:apply-templates/></block>
</xsl:template>-->

<!--<xsl:template match="*[contains(@class,' topic/desc ')]">
    <block compact="yes"><xsl:apply-templates/></block>
</xsl:template>-->

<!--<xsl:template match="*[contains(@class,' topic/linkinfo ')]">
    <block compact="yes"><xsl:apply-templates/></block>
</xsl:template>-->

<!--<xsl:template match="*[contains(@class,' topic/link ')]">
    <xsl:choose>
        <xsl:when test="*[contains(@class,' topic/linktext ')]">
            <block compact="yes"><xsl:apply-templates/></block>
        </xsl:when>
        <xsl:when test="@href">
            <block compact="yes"><text><xsl:value-of select="@href"/></text><xsl:apply-templates/></block>
        </xsl:when>
        <xsl:otherwise>
            <block compact="yes"><xsl:apply-templates/></block>
        </xsl:otherwise>
    </xsl:choose>
</xsl:template>

<xsl:template match="*[contains(@class,' topic/linktext ')]">
    <block compact="yes"><xsl:apply-templates/></block>
</xsl:template>-->

<!-- Add for "New <data> element (#9)" in DITA 1.1 -->
<xsl:template match="*[contains(@class,' topic/data ')]"/>

<!-- Add for "Support foreign content vocabularies such as 
     MathML and SVG with <unknown> (#35) " in DITA 1.1 -->
<xsl:template match="*[contains(@class,' topic/foreign ') or contains(@class,' topic/unknown ')]"/>

</xsl:stylesheet>
