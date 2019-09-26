<?xml version="1.0" encoding="UTF-8" ?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2004, 2005 IBM Corporation

See the accompanying LICENSE file for applicable license.
-->

<xsl:stylesheet version="2.0"
     xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
     xmlns:related-links="http://dita-ot.sourceforge.net/ns/200709/related-links"
     xmlns:dita2html="http://dita-ot.sourceforge.net/ns/200801/dita2html"
     xmlns:xs="http://www.w3.org/2001/XMLSchema"
     exclude-result-prefixes="related-links xs dita2html">

<!-- == REFERENCE UNIQUE SUBSTRUCTURES == -->

  <xsl:template match="*[contains(@class,' reference/properties ')]" name="reference.properties">
    <xsl:call-template name="spec-title"/>
    <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
    <xsl:call-template name="setaname"/>
    <table cellpadding="4" cellspacing="0"><!--summary=""-->
      <xsl:call-template name="setid"/>
      <xsl:attribute name="border" select="if (@frame = 'none') then 0 else 1"/>
      <xsl:call-template name="commonattributes">
        <xsl:with-param name="default-output-class">
          <xsl:choose>
            <xsl:when test="@frame = 'none'">simpletablenoborder</xsl:when>
            <xsl:otherwise>simpletableborder</xsl:otherwise>
          </xsl:choose>
        </xsl:with-param>
      </xsl:call-template>
      <xsl:apply-templates select="." mode="generate-table-summary-attribute"/>
      <xsl:call-template name="setscale"/>
      <xsl:call-template name="dita2html:simpletable-cols"/>
      
      <xsl:variable name="header" select="*[contains(@class,' reference/prophead ')]"/>
      <xsl:variable name="properties" select="*[contains(@class,' reference/property ')]"/>
      <xsl:variable name="hasType" select="exists($header/*[contains(@class,' reference/proptypehd ')] | $properties/*[contains(@class,' reference/proptype ')])"/>
      <xsl:variable name="hasValue" select="exists($header/*[contains(@class,' reference/propvaluehd ')] | $properties/*[contains(@class,' reference/propvalue ')])"/>
      <xsl:variable name="hasDesc" select="exists($header/*[contains(@class,' reference/propdeschd ')] | $properties/*[contains(@class,' reference/propdesc ')])"/>
      
      <xsl:variable name="prophead" as="element()">
        <xsl:choose>
          <xsl:when test="*[contains(@class, ' reference/prophead ')]">
            <xsl:sequence select="*[contains(@class, ' reference/prophead ')]"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:variable name="gen" as="element(gen)?">
              <xsl:call-template name="gen-prophead">
                <xsl:with-param name="hasType" select="$hasType"/>
                <xsl:with-param name="hasValue" select="$hasValue"/>
                <xsl:with-param name="hasDesc" select="$hasDesc"/>
              </xsl:call-template>
            </xsl:variable>
            <xsl:sequence select="$gen/*"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      <xsl:apply-templates select="$prophead">
        <xsl:with-param name="hasType" select="$hasType"/>
        <xsl:with-param name="hasValue" select="$hasValue"/>
        <xsl:with-param name="hasDesc" select="$hasDesc"/>
      </xsl:apply-templates>
      <tbody>    
        <xsl:apply-templates select="*[contains(@class, ' reference/property ')] | processing-instruction()">
          <xsl:with-param name="hasType" select="$hasType"/>
          <xsl:with-param name="hasValue" select="$hasValue"/>
          <xsl:with-param name="hasDesc" select="$hasDesc"/>
        </xsl:apply-templates>
      </tbody>
    </table>
    <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
    <xsl:value-of select="$newline"/>
  </xsl:template>

  <xsl:template name="gen-prophead" as="element(gen)?">
    <xsl:param name="hasType" as="xs:boolean"/>
    <xsl:param name="hasValue" as="xs:boolean"/>
    <xsl:param name="hasDesc" as="xs:boolean"/>
    <!-- Generated header needs to be wrapped in gen element to allow correct language detection -->
    <gen>
      <xsl:copy-of select="ancestor-or-self::*[@xml:lang][1]/@xml:lang"/>
      <prophead class="- topic/sthead reference/prophead ">
        <xsl:if test="$hasType">
         <proptypehd class="- topic/stentry reference/proptypehd " id="{generate-id()}-type">
           <xsl:call-template name="getVariable">
             <xsl:with-param name="id" select="'Type'"/>
           </xsl:call-template>
         </proptypehd>
        </xsl:if>
        <xsl:if test="$hasValue">
          <propvaluehd class="- topic/stentry reference/propvaluehd " id="{generate-id()}-value">
           <xsl:call-template name="getVariable">
             <xsl:with-param name="id" select="'Value'"/>
           </xsl:call-template>
         </propvaluehd>
        </xsl:if>
        <xsl:if test="$hasDesc">
          <xsl:call-template name="gen-propdeschd"/>
        </xsl:if>
      </prophead>
    </gen>
  </xsl:template>
  
  <xsl:template name="gen-propdeschd">
    <xsl:variable name="properties" select="ancestor-or-self::*[contains(@class,' reference/properties ')][1]"/>
    <propdeschd class="- topic/stentry reference/propdeschd " id="{generate-id($properties)}-desc">
      <xsl:call-template name="getVariable">
        <xsl:with-param name="id" select="'Description'"/>
      </xsl:call-template>
    </propdeschd>
  </xsl:template>

  <xsl:template match="*[contains(@class,' reference/properties ')]" mode="dita2html:get-max-entry-count" as="xs:integer">
    <xsl:sequence select="3"/>
  </xsl:template>

<!-- Process the header row in a properties table -->
<xsl:template match="*[contains(@class,' reference/prophead ')]" name="topic.reference.prophead">
  <xsl:param name="hasType" as="xs:boolean"/>
  <xsl:param name="hasValue" as="xs:boolean"/>
  <xsl:param name="hasDesc" as="xs:boolean"/>
  <thead>
  <tr>
   <xsl:call-template name="setid"/>
   <xsl:call-template name="commonattributes"/>
   <xsl:value-of select="$newline"/>
     <!-- For each of the 3 entry types: If the entry is in this row, apply-templates.
          Otherwise, if it is ever in this table, create empty entry, and add ID for accessibility. -->
     <xsl:choose>      <!-- Process <proptype> -->
       <xsl:when test="*[contains(@class,' reference/proptypehd ')]">
         <xsl:apply-templates select="*[contains(@class,' reference/proptypehd ')]"/>
       </xsl:when>
       <xsl:when test="$hasType">
         <th>
           <xsl:call-template name="style">
             <xsl:with-param name="contents">
               <xsl:text>vertical-align:bottom;</xsl:text>
               <xsl:call-template name="th-align"/>
             </xsl:with-param>
           </xsl:call-template>           
           <xsl:attribute name="id"><xsl:value-of select="generate-id(parent::*)"/>-type</xsl:attribute>
           <xsl:call-template name="getVariable">
             <xsl:with-param name="id" select="'Type'"/>
           </xsl:call-template>
         </th><xsl:value-of select="$newline"/>
       </xsl:when>
     </xsl:choose>
     <xsl:choose>      <!-- Process <propvalue> -->
       <xsl:when test="*[contains(@class,' reference/propvaluehd ')]">
         <xsl:apply-templates select="*[contains(@class,' reference/propvaluehd ')]"/>
       </xsl:when>
       <xsl:when test="$hasValue">
         <th>
           <xsl:call-template name="style">
             <xsl:with-param name="contents">
               <xsl:text>vertical-align:bottom;</xsl:text>
               <xsl:call-template name="th-align"/>
             </xsl:with-param>
           </xsl:call-template>
           <xsl:attribute name="id"><xsl:value-of select="generate-id(parent::*)"/>-value</xsl:attribute>
           <xsl:call-template name="getVariable">
             <xsl:with-param name="id" select="'Value'"/>
           </xsl:call-template>
         </th><xsl:value-of select="$newline"/>
       </xsl:when>
     </xsl:choose>
     <xsl:choose>      <!-- Process <propdesc> -->
       <xsl:when test="*[contains(@class,' reference/propdeschd ')]">
         <xsl:apply-templates select="*[contains(@class,' reference/propdeschd ')]"/>
       </xsl:when>
       <xsl:when test="$hasDesc">
         <xsl:variable name="propdeschd" as="element()">
           <xsl:call-template name="gen-propdeschd"/>
         </xsl:variable>
         <th>
           <xsl:call-template name="style">
             <xsl:with-param name="contents">
               <xsl:text>vertical-align:bottom;</xsl:text>
               <xsl:call-template name="th-align"/>
             </xsl:with-param>
           </xsl:call-template>           
           <xsl:attribute name="id"><xsl:value-of select="generate-id(parent::*)"/>-desc</xsl:attribute>
           <xsl:call-template name="getVariable">
             <xsl:with-param name="id" select="'Description'"/>
           </xsl:call-template>
         </th><xsl:value-of select="$newline"/>
       </xsl:when>
     </xsl:choose>
  </tr>
  </thead>
</xsl:template>

<!-- Add the headers attribute to a cell inside the properties table. This may be called from either
     a <property> row or from a cell inside the row. -->
<xsl:template name="addPropertiesHeadersAttribute">
  <xsl:param name="classVal"/>
  <xsl:param name="elementType"/>
  <xsl:attribute name="headers">
    <xsl:choose>
      <!-- First choice: if there is a matching cell inside a user-specified header, and it has an ID -->
      <xsl:when test="ancestor::*[contains(@class,' reference/properties ')]/*[1][contains(@class,' reference/prophead ')]/*[contains(@class,$classVal)]/@id">
        <xsl:value-of select="ancestor::*[contains(@class,' reference/properties ')]/*[1][contains(@class,' reference/prophead ')]/*[contains(@class,$classVal)]/@id"/>
      </xsl:when>
      <!-- Second choice: if there is a matching cell inside a user-specified header, use its generated ID -->
      <xsl:when test="ancestor::*[contains(@class,' reference/properties ')]/*[1][contains(@class,' reference/prophead ')]/*[contains(@class,$classVal)]">
        <xsl:value-of select="generate-id(ancestor::*[contains(@class,' reference/properties ')]/*[1][contains(@class,' reference/prophead ')]/*[contains(@class,$classVal)])"/>
      </xsl:when>
      <!-- Third choice: no user-specified header for this column. ID is based on the table's generated ID. -->
      <xsl:otherwise>
        <xsl:value-of select="generate-id(ancestor::*[contains(@class,' reference/properties ')])"/>-<xsl:value-of select="$elementType"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:attribute>
</xsl:template>

<!-- Process a standard row in the properties table. Apply-templates on the entries one at a time;
     if one is missing which should be present, create an empty cell. -->
<xsl:template match="*[contains(@class,' reference/property ')]" name="topic.reference.property">
  <xsl:param name="hasType" as="xs:boolean"/>
  <xsl:param name="hasValue" as="xs:boolean"/>
  <xsl:param name="hasDesc" as="xs:boolean"/>
  <tr>
   <xsl:call-template name="setid"/>
   <xsl:call-template name="commonattributes"/>
   <xsl:value-of select="$newline"/>
     <!-- For each of the 3 entry types:
          - If it is in this row, apply
          - Otherwise, if it is in the table at all, create empty entry -->
     <xsl:choose>      <!-- Process or create proptype -->
       <xsl:when test="*[contains(@class,' reference/proptype ')]">
         <xsl:apply-templates select="*[contains(@class,' reference/proptype ')]"/>
       </xsl:when>
       <xsl:when test="$hasType">
         <td>    <!-- Create an empty cell. Add accessiblity attribute. -->
           <xsl:call-template name="addPropertiesHeadersAttribute">
             <xsl:with-param name="classVal"> reference/proptypehd </xsl:with-param>
             <xsl:with-param name="elementType">type</xsl:with-param>
           </xsl:call-template>
           <xsl:text>&#xA0;</xsl:text>
         </td>
         <xsl:value-of select="$newline"/>
       </xsl:when>
     </xsl:choose>
     <xsl:choose>      <!-- Process or create propvalue -->
       <xsl:when test="*[contains(@class,' reference/propvalue ')]">
         <xsl:apply-templates select="*[contains(@class,' reference/propvalue ')]"/>
       </xsl:when>
       <xsl:when test="$hasValue">
         <td>    <!-- Create an empty cell. Add accessiblity attribute. -->
           <xsl:call-template name="addPropertiesHeadersAttribute">
             <xsl:with-param name="classVal"> reference/propvaluehd </xsl:with-param>
             <xsl:with-param name="elementType">value</xsl:with-param>
           </xsl:call-template>
           <xsl:text>&#xA0;</xsl:text>
         </td>
         <xsl:value-of select="$newline"/>
       </xsl:when>
     </xsl:choose>
     <xsl:choose>      <!-- Process or create propdesc -->
       <xsl:when test="*[contains(@class,' reference/propdesc ')]">
         <xsl:apply-templates select="*[contains(@class,' reference/propdesc ')]"/>
       </xsl:when>
       <xsl:when test="$hasDesc">
         <td>    <!-- Create an empty cell. Add accessiblity attribute. -->
           <xsl:call-template name="addPropertiesHeadersAttribute">
             <xsl:with-param name="classVal"> reference/propdeschd </xsl:with-param>
             <xsl:with-param name="elementType">desc</xsl:with-param>
           </xsl:call-template>
           <xsl:text>&#xA0;</xsl:text>
         </td>
         <xsl:value-of select="$newline"/>
       </xsl:when>
     </xsl:choose>
  </tr>
  <xsl:value-of select="$newline"/>
</xsl:template>

<xsl:template match="*[contains(@class,' reference/proptype ')]" name="topic.reference.proptype">
  <xsl:apply-templates select="." mode="propertiesEntry">
    <xsl:with-param name="elementType">type</xsl:with-param>
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="*[contains(@class,' reference/propvalue ')]" name="topic.reference.propvalue">
  <xsl:apply-templates select="." mode="propertiesEntry">
    <xsl:with-param name="elementType">value</xsl:with-param>
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="*[contains(@class,' reference/propdesc ')]" name="topic.reference.propdesc">
  <xsl:apply-templates select="." mode="propertiesEntry">
    <xsl:with-param name="elementType">desc</xsl:with-param>
  </xsl:apply-templates>
</xsl:template>

<!-- Template based on the stentry template in dit2htm. Only change is to add elementType
     paramenter, and call addPropertiesHeadersAttribute instead of output-stentry-headers. -->
<xsl:template match="*" mode="propertiesEntry">
  <xsl:param name="elementType"/>
  
  <xsl:variable name="localkeycol" as="xs:integer">
    <xsl:choose>
      <xsl:when test="ancestor::*[contains(@class,' topic/simpletable ')][1]/@keycol">
        <xsl:value-of select="ancestor::*[contains(@class,' topic/simpletable ')][1]/@keycol"/>
      </xsl:when>
      <xsl:otherwise>0</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="element-name" as="xs:string">
    <xsl:choose>
      <xsl:when test="$localkeycol = 1 and $elementType = 'type'">th</xsl:when>
      <xsl:when test="$localkeycol = 2 and $elementType = 'value'">th</xsl:when>
      <xsl:when test="$localkeycol = 3 and $elementType = 'desc'">th</xsl:when>
      <xsl:otherwise>td</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:element name="{$element-name}">
    <xsl:call-template name="style">
      <xsl:with-param name="contents">
        <xsl:text>vertical-align:top;</xsl:text>     
      </xsl:with-param>
    </xsl:call-template>
    <xsl:call-template name="output-stentry-id"/>
    <xsl:call-template name="addPropertiesHeadersAttribute">
      <xsl:with-param name="classVal"> reference/prop<xsl:value-of select="$elementType"/>hd<xsl:text> </xsl:text></xsl:with-param>
      <xsl:with-param name="elementType" select="$elementType"/>
    </xsl:call-template>
    <xsl:call-template name="commonattributes"/>
    <xsl:apply-templates select="../*[contains(@class,' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
    <xsl:call-template name="propentry-templates"/>
    <xsl:apply-templates select="../*[contains(@class,' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  </xsl:element>
  <xsl:value-of select="$newline"/>
</xsl:template>

<xsl:template name="propentry-templates">
 <xsl:choose>
  <xsl:when test="*[not(contains(@class,' ditaot-d/startprop ') or contains(@class,' dita-ot/endprop '))] | text() | processing-instruction()">
   <xsl:apply-templates/>
  </xsl:when>
  <xsl:otherwise>
    <!-- Add flags, then either @specentry or NBSP -->
    <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
    <xsl:choose>
      <xsl:when test="@specentry"><xsl:value-of select="@specentry"/></xsl:when>
      <xsl:otherwise>&#160;</xsl:otherwise>
    </xsl:choose>
    <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  </xsl:otherwise>
 </xsl:choose>
</xsl:template>

  <!-- References have their own group. -->
  <xsl:template match="*[contains(@class, ' topic/link ')][@type='reference']" mode="related-links:get-group"
                name="related-links:group.reference"
                as="xs:string">
    <xsl:text>reference</xsl:text>
  </xsl:template>
  
  <!-- Priority of reference group. -->
  <xsl:template match="*[contains(@class, ' topic/link ')][@type='reference']" mode="related-links:get-group-priority"
                name="related-links:group-priority.reference"
                as="xs:integer">
    <xsl:sequence select="1"/>
  </xsl:template>
  
  <!-- Reference wrapper for HTML: "Related reference" in <div>. -->
  <xsl:template match="*[contains(@class, ' topic/link ')][@type='reference']" mode="related-links:result-group"
                name="related-links:result.reference" as="element()?">
    <xsl:param name="links"/>
    <xsl:if test="normalize-space(string-join($links, ''))">
      <linklist class="- topic/linklist " outputclass="relinfo relref">
        <xsl:copy-of select="ancestor-or-self::*[@xml:lang][1]/@xml:lang"/>
        <title class="- topic/title ">
          <xsl:call-template name="getVariable">
            <xsl:with-param name="id" select="'Related reference'"/>
          </xsl:call-template>
        </title>
        <xsl:copy-of select="$links"/>
      </linklist>
    </xsl:if>
  </xsl:template>
</xsl:stylesheet>
