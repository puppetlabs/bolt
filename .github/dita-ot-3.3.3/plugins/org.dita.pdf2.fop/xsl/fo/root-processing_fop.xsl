<?xml version="1.0" encoding="UTF-8"?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2012 Jarno Elovirta

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:fo="http://www.w3.org/1999/XSL/Format"
                xmlns:x="adobe:ns:meta/"
                xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                xmlns:dc="http://purl.org/dc/elements/1.1/"
                xmlns:xmp="http://ns.adobe.com/xap/1.0/"
                xmlns:pdf="http://ns.adobe.com/pdf/1.3/"
                xmlns:dita-ot="http://dita-ot.sourceforge.net/ns/201007/dita-ot"
                version="2.0" exclude-result-prefixes="dita-ot xs">
    
  <xsl:template match="/" name="rootTemplate">
    <xsl:call-template name="validateTopicRefs"/>
    <fo:root xsl:use-attribute-sets="__fo__root">
      <xsl:call-template name="createLayoutMasters"/>
      <xsl:call-template name="createMetadata"/>
      <xsl:call-template name="createBookmarks"/>
      <xsl:apply-templates select="*" mode="generatePageSequences"/>
    </fo:root>
  </xsl:template>
  
  <xsl:template match="document-node()[*[contains(@class, ' topic/topic ')]]">
    <fo:root xsl:use-attribute-sets="__fo__root">
      <xsl:call-template name="createLayoutMasters"/>
      <xsl:call-template name="createMetadata"/>
      <xsl:call-template name="createBookmarks"/>
      <xsl:apply-templates/>
    </fo:root>
  </xsl:template>
    
  <xsl:template name="createMetadata">
    <fo:declarations>
      <x:xmpmeta>
        <rdf:RDF>
          <rdf:Description rdf:about="">
            <xsl:variable name="title" as="xs:string?">
              <xsl:apply-templates select="." mode="dita-ot:title-metadata"/>
            </xsl:variable>
            <xsl:if test="exists($title)">
              <dc:title>
                <xsl:value-of select="$title"/>
              </dc:title>
            </xsl:if>
            <xsl:variable name="author" as="xs:string?">
              <xsl:apply-templates select="." mode="dita-ot:author-metadata"/>
            </xsl:variable>
            <xsl:if test="exists($author)">
              <dc:creator>
                <xsl:value-of select="$author"/>
              </dc:creator>
            </xsl:if>
            <xsl:variable name="keywords" as="xs:string*">
              <xsl:apply-templates select="." mode="dita-ot:keywords-metadata"/>
            </xsl:variable>
            <xsl:if test="exists($keywords)">
              <pdf:Keywords>
                <xsl:value-of select="$keywords" separator=", "/>
              </pdf:Keywords>
            </xsl:if>
            <xsl:variable name="subject" as="xs:string?">
              <xsl:apply-templates select="." mode="dita-ot:subject-metadata"/>
            </xsl:variable>
            <xsl:if test="exists($subject)">
              <dc:description>
                <rdf:Alt>
                  <rdf:li xml:lang="x-default">
                    <xsl:value-of select="$subject"/>
                  </rdf:li>
                </rdf:Alt>
              </dc:description>
            </xsl:if>
            <xmp:CreatorTool>DITA Open Toolkit</xmp:CreatorTool>
          </rdf:Description>
        </rdf:RDF>
      </x:xmpmeta>
    </fo:declarations>
  </xsl:template>

</xsl:stylesheet>
