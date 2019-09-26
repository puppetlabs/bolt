<?xml version="1.0" encoding="UTF-8"?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2016 Jarno Elovirta

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:dita2html="http://dita-ot.sourceforge.net/ns/200801/dita2html"
                xmlns:ditamsg="http://dita-ot.sourceforge.net/ns/200704/ditamsg"                
                xmlns:dita-ot="http://dita-ot.sourceforge.net/ns/201007/dita-ot"
                xmlns:table="http://dita-ot.sourceforge.net/ns/201007/dita-ot/table"
                xmlns:simpletable="http://dita-ot.sourceforge.net/ns/201007/dita-ot/simpletable"
                version="2.0"
                exclude-result-prefixes="xs dita2html ditamsg dita-ot table simpletable">

  <xsl:template match="*[contains(@class, ' topic/simpletable ')]" mode="generate-table-summary-attribute">
    <!-- Override this to use a local convention for setting table's @summary attribute,
         until OASIS provides a standard mechanism for setting. -->
  </xsl:template>
  
  
  <xsl:template name="dita2html:simpletable-cols">
    <xsl:variable name="col-count" as="xs:integer">
      <xsl:apply-templates select="." mode="dita2html:get-max-entry-count"/>
    </xsl:variable>
    <xsl:variable name="col-widths" as="xs:double*">
      <xsl:variable name="widths" select="tokenize(normalize-space(translate(@relcolwidth, '*', '')), '\s+')" as="xs:string*"/>
      <xsl:for-each select="$widths">
        <xsl:choose>
          <xsl:when test=". castable as xs:double">
            <xsl:sequence select="xs:double(.)"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:sequence select="xs:double(1)"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:for-each>
      <xsl:for-each select="1 to ($col-count - count($widths))">
        <xsl:sequence select="xs:double(1)"/>
      </xsl:for-each>
    </xsl:variable>
    <xsl:variable name="col-widths-sum" select="sum($col-widths)"/>
    <colgroup>
      <xsl:for-each select="$col-widths">
        <col style="width:{(. div $col-widths-sum) * 100}%"/>
      </xsl:for-each>
    </colgroup>
  </xsl:template>
  
  <xsl:template match="*[contains(@class, ' topic/simpletable ')]" mode="dita2html:get-max-entry-count" as="xs:integer">
    <xsl:variable name="counts" as="xs:integer*">
      <xsl:for-each select="*[contains(@class, ' topic/sthead ')] |
        *[contains(@class, ' topic/strow ')]">
        <xsl:sequence select="count(*[contains(@class, ' topic/stentry ')])"/>
      </xsl:for-each>
    </xsl:variable>
    <xsl:sequence select="max($counts)"/>
  </xsl:template>
    
  <!-- Output the ID for a simpletable entry, when it is specified. If no ID is specified,
       and this is a header row, generate an ID. The entry is considered a header entry
       when the it is inside <sthead>, or when it is in the column specified in the keycol
       attribute on <simpletable>
       NOTE: It references simpletable with parent::*/parent::* in order to avoid problems
       with nested simpletables. -->
  <!-- Deprecated in 3.0 in favor of HTML5 @scope attribute. -->
  <xsl:template name="output-stentry-id">
    <!-- Find the position in this row -->
    <xsl:variable name="thiscolnum"><xsl:number level="single" count="*[contains(@class, ' topic/stentry ')]"/></xsl:variable>
    <xsl:choose>
      <xsl:when test="@id">    <!-- If ID is specified, always use it -->
        <xsl:attribute name="id" select="dita-ot:generate-html-id(.)"/>
      </xsl:when>
      <!-- If no ID is specified, and this is a header cell, generate an ID -->
      <xsl:when test="parent::*[contains(@class, ' topic/sthead ')] or
        (parent::*/parent::*/@keycol and number(parent::*/parent::*/@keycol) = number($thiscolnum))">
        <xsl:attribute name="id" select="generate-id(.)"/>
      </xsl:when>
    </xsl:choose>
  </xsl:template>
  
  <!-- Output the headers attribute for screen readers. If specified, it should match both
       of the following:
       * the <stentry> with the same position in the sthead
       * the <stentry> that is in the key column (specified in @keycol on simpletable)
       Note: This function is not called within sthead, so sthead never gets headers.
       NOTE: I reference simpletable with parent::*/parent::* in order to avoid problems
       with nested simpletables. -->
  <!-- Deprecated in 3.0 in favor of HTML5 @scope attribute -->
  <xsl:template name="set.stentry.headers">
    <xsl:variable name="keycol" select="parent::*/parent::*/@keycol"/>
    <xsl:if test="$keycol | parent::*/parent::*/*[contains(@class, ' topic/sthead ')]">
      <xsl:variable name="thiscolnum"><xsl:number level="single" count="*[contains(@class, ' topic/stentry ')]"/></xsl:variable>
      
      <!-- If there is a keycol, and this is not the key column, get the ID for the keycol -->
      <xsl:variable name="keycolhead">
        <xsl:if test="$keycol and $thiscolnum != number($keycol)">
          <xsl:variable name="col" select="../*[number($keycol)]"/>
          <xsl:choose>
            <xsl:when test="$col/@id">
              <xsl:value-of select="$col/@id"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="generate-id($col)"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:if>
      </xsl:variable>
      
      <!-- If there is a header, get the ID from the head cell in this column.
             Go up to simpletable, into the row, to the entry at column $thiscolnum -->
      <xsl:variable name="header">
        <xsl:if test="parent::*/parent::*/*[contains(@class, ' topic/sthead ')]/*[contains(@class, ' topic/stentry ')][number($thiscolnum)]">
          <xsl:value-of select="dita-ot:generate-html-id(parent::*/parent::*/*[contains(@class, ' topic/sthead ')]/*[contains(@class, ' topic/stentry ')][number($thiscolnum)])"/>
        </xsl:if>
      </xsl:variable>
      
      <!-- If there is a keycol header or an sthead header, create the attribute -->
      <xsl:if test="string-length($header) > 0 or string-length($keycolhead) > 0">
        <xsl:attribute name="headers">
          <xsl:value-of select="$header"/>
          <xsl:if test="string-length($header) > 0 and string-length($keycolhead) > 0"><xsl:text> </xsl:text></xsl:if>
          <xsl:value-of select="$keycolhead"/>
        </xsl:attribute>
      </xsl:if>
    </xsl:if>
  </xsl:template>
  
  <!-- For simple table headers: <TH> Set align="right" when in a BIDI area -->
  <xsl:template name="th-align">
    <xsl:variable name="biditest" as="xs:boolean">
      <xsl:call-template name="bidi-area"/>
    </xsl:variable>
    <xsl:text>text-align:</xsl:text>
    <xsl:value-of select="if ($biditest) then 'right' else 'left'"/>
    <xsl:text>;</xsl:text>
  </xsl:template>
  
  <xsl:template name="stentry-templates">
    <xsl:choose>
      <xsl:when test="not(*|text()|processing-instruction()) and @specentry">
        <xsl:value-of select="@specentry"/>
      </xsl:when>
      <xsl:when test="not(*|text()|processing-instruction())">
        <xsl:text>&#160;</xsl:text>  <!-- nbsp -->
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:function name="simpletable:generate-headers" as="xs:string">
    <xsl:param name="el" as="element()"/>
    <xsl:param name="suffix" as="xs:string"/>
    <xsl:sequence select="string-join((generate-id($el), $suffix), '-')"/>
  </xsl:function>
  
  <xsl:template match="*[contains(@class,' topic/simpletable ')]
    [empty(*[contains(@class,' topic/strow ')]/*[contains(@class,' topic/stentry ')])]" priority="10"/>
  <xsl:template match="*[contains(@class,' topic/strow ') or contains(@class,' topic/sthead ')][empty(*[contains(@class,' topic/stentry ')])]" priority="10"/>

  <xsl:template match="*[contains(@class, ' topic/simpletable ')]" name="topic.simpletable">
    <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>

    <xsl:call-template name="spec-title"/>
    <table>
      <xsl:apply-templates select="." mode="table:common"/>
      <xsl:call-template name="dita2html:simpletable-cols"/>

      <xsl:apply-templates select="*[contains(@class, ' topic/sthead ')]"/>
      <xsl:apply-templates select="." mode="generate-table-header"/>

      <tbody>
        <xsl:apply-templates select="*[contains(@class, ' topic/strow ')]"/>
      </tbody>
    </table>

    <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/simpletable ')]" mode="css-class">
    <xsl:apply-templates select="@frame, @expanse, @scale" mode="#current"/>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/strow ')]" name="topic.strow">
    <tr>
      <xsl:apply-templates select="." mode="table:common"/>
      <xsl:apply-templates/>
    </tr>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/sthead ')]" name="topic.sthead">
    <thead>
      <tr>
        <xsl:apply-templates select="." mode="table:common"/>
        <xsl:apply-templates/>
      </tr>
    </thead>
  </xsl:template>

  <xsl:template match="*[simpletable:is-head-entry(.)]">
    <th>
      <xsl:apply-templates select="." mode="simpletable:entry"/>
    </th>
  </xsl:template>

  <xsl:template match="*[simpletable:is-body-entry(.)][simpletable:is-keycol-entry(.)]">
    <th scope="row">
      <xsl:apply-templates select="." mode="simpletable:entry"/>
    </th>
  </xsl:template>

  <xsl:template match="*[simpletable:is-body-entry(.)][not(simpletable:is-keycol-entry(.))]" name="topic.stentry">
    <td>
      <xsl:apply-templates select="." mode="simpletable:entry"/>
    </td>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/stentry ')]" mode="simpletable:entry">
    <xsl:apply-templates select="." mode="table:common"/>
    <xsl:apply-templates select="." mode="headers"/>
    <xsl:choose>
      <xsl:when test="*|text()|processing-instruction()">
        <xsl:apply-templates/>
      </xsl:when>
      <xsl:when test="@specentry">
        <xsl:apply-templates select="@specentry"/>
      </xsl:when>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="*[simpletable:is-head-entry(.)]" mode="headers">
    <xsl:attribute name="scope" select="'col'"/>
  </xsl:template>

  <xsl:template match="*[simpletable:is-body-entry(.)]" mode="headers">
    <xsl:if test="simpletable:is-keycol-entry(.)">
      <xsl:attribute name="scope" select="'row'"/>
    </xsl:if>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/simpletable ')]" mode="generate-table-header" priority="10">
    <xsl:variable name="gen" as="element(gen)">
      <!--
      Generated header needs to be wrapped in gen element to allow correct
      language detection.
      -->
      <gen>
        <xsl:copy-of select="ancestor-or-self::*[@xml:lang][1]/@xml:lang"/>
        <xsl:next-match/>
      </gen>
    </xsl:variable>
    
    <xsl:apply-templates select="$gen/*"/>
  </xsl:template>

</xsl:stylesheet>
