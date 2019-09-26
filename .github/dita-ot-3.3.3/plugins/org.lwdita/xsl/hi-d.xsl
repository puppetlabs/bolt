<?xml version="1.0" encoding="UTF-8" ?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version="2.0">
  
  <xsl:template match="*[contains(@class,' hi-d/b ')]" name="topic.hi-d.b">
   <strong>
     <xsl:call-template name="commonattributes"/>
     <xsl:call-template name="setidaname"/>
     <xsl:apply-templates/>
    </strong>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' hi-d/i ')]" name="topic.hi-d.i">
   <emph>
     <xsl:call-template name="commonattributes"/>
     <xsl:call-template name="setidaname"/>
     <xsl:apply-templates/>
    </emph>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' hi-d/u ')]" name="topic.hi-d.u">
   <span>
     <xsl:call-template name="commonattributes"/>
     <xsl:call-template name="setidaname"/>
     <xsl:apply-templates/>
    </span>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' hi-d/tt ')]" name="topic.hi-d.tt">
   <code>
     <xsl:call-template name="commonattributes"/>
     <xsl:call-template name="setidaname"/>
     <xsl:apply-templates/>
    </code>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' hi-d/sup ')]" name="topic.hi-d.sup">
   <superscript>
      <xsl:call-template name="commonattributes"/>
      <xsl:call-template name="setidaname"/>
      <xsl:apply-templates/>
   </superscript>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' hi-d/sub ')]" name="topic.hi-d.sub">
   <subscript>
      <xsl:call-template name="commonattributes"/>
      <xsl:call-template name="setidaname"/>
      <xsl:apply-templates/>
    </subscript>
  </xsl:template>

  <xsl:template match="*[contains(@class,' hi-d/line-through ')]" name="topic.hi-d.line-through">
    <span style="text-decoration:line-through">
      <xsl:call-template name="commonattributes"/>
      <xsl:call-template name="setidaname"/>
      <xsl:apply-templates/>
    </span>
  </xsl:template>

  <xsl:template match="*[contains(@class,' hi-d/overline ')]" name="topic.hi-d.overline">
    <span style="text-decoration:overline">
      <xsl:call-template name="commonattributes"/>
      <xsl:call-template name="setidaname"/>
      <xsl:apply-templates/>
    </span>
  </xsl:template>  

</xsl:stylesheet>
