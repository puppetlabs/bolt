<?xml version="1.0" encoding="UTF-8"?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2010 IBM Corporation

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet version="2.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:dita2html="http://dita-ot.sourceforge.net/ns/200801/dita2html"
    xmlns:related-links="http://dita-ot.sourceforge.net/ns/200709/related-links">
    
    <xsl:import href="plugin:org.dita.xhtml:xsl/dita2xhtml.xsl"/>
    
    <xsl:variable name="pluginfilename" select="concat($WORKDIR, $PATH2PROJ, 'pluginId.xml')"/>
    
    <!-- avoid java.net exception -->
    <xsl:variable name="PLUGINFILE">
        <xsl:choose>
            <xsl:when test="starts-with($pluginfilename, '/')">
                <xsl:value-of select="concat('file://', $pluginfilename)"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="concat('file:/', $pluginfilename)"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:variable>
    <!-- avoid java.net exception -->
    <xsl:variable name="keydef" select="concat($WORKDIR, $PATH2PROJ, 'keydef.xml')"/>
    <xsl:variable name="KEYDEFFILE">
        <xsl:choose>
            <xsl:when test="starts-with($keydef, '/')">
                <xsl:value-of select="concat('file://', $keydef)"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="concat('file:/', $keydef)"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:variable>
    
    <xsl:param name="FILENAME"/>
    <xsl:param name="FILEDIR"/>
    <xsl:param name="CURRENTFILE" select="concat($FILEDIR, '/', $FILENAME)"/>
    
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <!--dita2htmlImpl.xsl-->
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="root_element">
        <!--xsl:apply-templates select="." mode="conref"/-->
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="root_element">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="child.topic">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="child.topic">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="set-output-class">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="set-output-class">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="outputContentsWithFlags">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="outputContentsWithFlags">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="outofline">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="outofline">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="prereqs">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="prereqs">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="outputContentsWithFlagsAndStyle">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="outputContentsWithFlagsAndStyle">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="outofline.abstract">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="outofline.abstract">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="section-fmt">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="section-fmt">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="example-fmt">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="example-fmt">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="process.note">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="process.note">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="process.note.tip">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="process.note.tip">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="process.note.fastpath">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="process.note.fastpath">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="process.note.important">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="process.note.important">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="process.note.remember">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="process.note.remember">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="process.note.restriction">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="process.note.restriction">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="process.note.attention">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="process.note.attention">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="process.note.caution">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="process.note.caution">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="process.note.danger">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="process.note.danger">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="process.note.other">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="process.note.other">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="lq-fmt">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="lq-fmt">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="ul-fmt">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="ul-fmt">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="sl-fmt">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="sl-fmt">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="xref">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="xref">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="dl-fmt">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="dl-fmt">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="output-dt">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="output-dt">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="pull-in-title">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="pull-in-title">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="find-keyref-target">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="find-keyref-target">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="turning-to-link">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="turning-to-link">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="output-term">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="output-term">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="getMatchingSurfaceForm">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="getMatchingSurfaceForm">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="getMatchingAcronym">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="getMatchingAcronym">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="pre-fmt">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="pre-fmt">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="lines-fmt">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="lines-fmt">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="fig-fmt">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="fig-fmt">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="dita2html:get-default-fig-class">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="dita2html:get-default-fig-class">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="figgroup-fmt">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="figgroup-fmt">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="table-fmt">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="table-fmt">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="gen-tfoot">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="gen-tfoot">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="count-colwidth">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="count-colwidth">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="findmatch">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="findmatch">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="check-first-column">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="check-first-column">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="findmatch">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="findmatch">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="simpletable-fmt">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="simpletable-fmt">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="start-stentry-flagging">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="start-stentry-flagging">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="end-stentry-flagging">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="end-stentry-flagging">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="get-output-class">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="get-output-class">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="get-element-ancestry">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="get-element-ancestry">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="get-value-for-class">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="get-value-for-class">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="dita2html:section-heading">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="dita2html:section-heading">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="add-HDF">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="add-HDF">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="genEndnote">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="genEndnote">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="tabletitle">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="tabletitle">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="tabledesc">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="tabledesc">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="figtitle">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="figtitle">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="figdesc">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="figdesc">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="gen-user-head">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="gen-user-head">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="gen-user-header">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="gen-user-header">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="gen-user-footer">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="gen-user-footer">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="gen-user-sidetoc">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="gen-user-sidetoc">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="gen-user-scripts">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="gen-user-scripts">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="gen-user-styles">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="gen-user-styles">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="gen-user-external-link">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="gen-user-external-link">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="gen-user-panel-title-pfx">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="gen-user-panel-title-pfx">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="chapterHead">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="chapterHead">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="chapterBody">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="chapterBody">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="addAttributesToBody">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="addAttributesToBody">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="breadcrumb">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="breadcrumb">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="common-processing-phrase-within-link">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="common-processing-phrase-within-link">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="prereq-fmt">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="prereq-fmt">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    <!-- taskdisplay.xsl -->
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="steps-fmt">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="steps-fmt">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="steps">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="steps">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="stepsunord-fmt">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="stepsunord-fmt">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="onestep">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="onestep">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="onestep-fmt">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="onestep-fmt">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="substeps-fmt">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="substeps-fmt">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="substep-fmt">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="substep-fmt">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="choices-fmt">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="choices-fmt">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="choicetable-fmt">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="choicetable-fmt">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="chtabhdr">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="chtabhdr">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="related-links:get-group">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="related-links:get-group">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="related-links:get-group-priority">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="related-links:get-group-priority">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="related-links:result-group">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="related-links:result-group">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="propertiesEntry">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="propertiesEntry">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="related-links:group-unordered-links">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="related-links:group-unordered-links">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="determine-final-href">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="determine-final-href">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="parseHrefUptoExtension">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="parseHrefUptoExtension">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conref][@conref!=''][not(@conaction)]" mode="processlinklist">
        <xsl:apply-templates select="." mode="conref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*[@conkeyref]" mode="processlinklist">
        <xsl:apply-templates select="." mode="conkeyref"/>
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="*" mode="conref">
        <!-- file referenced by conref -->
        <xsl:variable name="FILENAME">
            <xsl:choose>
                <xsl:when test="contains(@conref,'#')">
                    <xsl:value-of select="substring-before(@conref,'#')"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="@conref"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <!-- topic id -->
        <xsl:variable name="topicid">
            <xsl:choose>
                <xsl:when test="contains(@conref,'#') and contains(substring-after(@conref,'#'),'/')"><xsl:value-of select="substring-before(substring-after(@conref,'#'),'/')"/></xsl:when>
                <xsl:when test="contains(@conref,'#')"><xsl:value-of select="substring-after(@conref,'#')"/></xsl:when>
                <xsl:otherwise>
                    <!-- get first topic id in the conref target file -->
                    <xsl:variable name="file" select="concat($WORKDIR, $PATH2PROJ, @conref)"/>
                    <xsl:variable name="element" select="local-name(.)"/>
                    <xsl:value-of select="document($file,/)//*[contains(@class, ' topic/topic ')][1][local-name()=$element]/@id"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <!-- element id -->
        <xsl:variable name="elemid">
            <xsl:choose>
                <xsl:when test="contains(@conref,'#') and contains(substring-after(@conref,'#'),'/')"><xsl:value-of select="substring-after(substring-after(@conref,'#'),'/')"/></xsl:when>
                <xsl:otherwise>#none#</xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <!-- plugin id -->
        <xsl:variable name="pluginId">
            <xsl:value-of select="(document($PLUGINFILE, /)//entry[@key='pluginId'])"/>
        </xsl:variable>
        <!-- create the include element -->
        <xsl:element name="include">
            <xsl:variable name="path">
                <xsl:choose>
                    <xsl:when test="not($elemid = '#none#' )">
                        <xsl:value-of select="$pluginId"/>/<xsl:value-of select="concat(substring-before(translate($FILENAME, '\', '/'), '.')
                            , '.html')"/>/<xsl:value-of select="$topicid"/>__<xsl:value-of select="$elemid"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="$pluginId"/>/<xsl:value-of select="concat(substring-before(translate($FILENAME, '\', '/'), '.')
                            , '.html')"/>/<xsl:value-of select="$topicid"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:variable>
            <xsl:attribute name="path">
                <xsl:value-of select="$path"/>
            </xsl:attribute>
        </xsl:element>
    </xsl:template>
    
    <!-- conkeyref -->
    <xsl:template match="*" mode="conkeyref">
        <!-- get key -->
        <xsl:variable name="key">
            <xsl:choose>
                <xsl:when test="contains(@conkeyref, '#')">
                    <xsl:value-of select="substring-before(@conkeyref, '#')"/>
                </xsl:when>
                <xsl:when test="contains(@conkeyref, '/' )">
                    <xsl:value-of select="substring-before(@conkeyref, '/')"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="@conkeyref"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <!-- element id -->
        <xsl:variable name="elemid">
            <xsl:choose>
                <xsl:when test="contains(@conkeyref,'/') "><xsl:value-of select="substring-after(@conkeyref,'/' )"/></xsl:when>
                <xsl:otherwise>#none#</xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <!-- get referenced key value -->
        <xsl:variable name="keyValue">
            <xsl:value-of select="document($KEYDEFFILE, /)//keydef[@keys=$key]/@href"/>
        </xsl:variable>
        <!-- get referred file -->
        <xsl:variable name="FILENAME">
            <xsl:choose>
                <xsl:when test="contains($keyValue,'#')">
                    <xsl:value-of select="substring-before($keyValue,'#')"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="$keyValue"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <!-- topic id -->
        <xsl:variable name="topicid">
            <xsl:choose>
                <xsl:when test="contains(@conkeyref,'#') and contains(substring-after(@conkeyref,'#'),'/')"><xsl:value-of select="substring-before(substring-after(@conkeyref,'#'),'/')"/></xsl:when>
                <xsl:when test="contains(@conkeyref,'#')"><xsl:value-of select="substring-after(@conkeyref,'#')"/></xsl:when>
                <xsl:when test="contains($keyValue,'#')"><xsl:value-of select="substring-after($keyValue,'#')"/></xsl:when>
                <xsl:otherwise>#none#</xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <!-- plugin id -->
        <xsl:variable name="pluginId">
            <xsl:value-of select="(document($PLUGINFILE, /)//entry[@key='pluginId'])"/>
        </xsl:variable>
        <!-- create the include element -->
        <xsl:element name="include">
            <xsl:variable name="path">
                <xsl:choose>
                    <xsl:when test="not($topicid = '#none#' ) and not($elemid = '#none#')">
                        <xsl:value-of select="$pluginId"/>/<xsl:value-of select="concat(substring-before(translate($FILENAME, '\', '/'), '.')
                            , '.html')"/>/<xsl:value-of select="$topicid"/>__<xsl:value-of select="$elemid"/>
                    </xsl:when>
                    <!-- has elemid -->
                    <xsl:when test="not($elemid = '#none#' )">
                        <!-- change the element id to topic id -->
                        <xsl:value-of select="$pluginId"/>/<xsl:value-of select="concat(substring-before(translate($FILENAME, '\', '/'), '.')
                            , '.html')"/>/<xsl:value-of select="$elemid"/>
                    </xsl:when>
                    <!-- has topicid -->
                    <xsl:when test="not($topicid = '#none#' )">
                        <xsl:value-of select="$pluginId"/>/<xsl:value-of select="concat(substring-before(translate($FILENAME, '\', '/'), '.')
                            , '.html')"/>/<xsl:value-of select="$topicid"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <!-- both elemid and topicid are '#none' -->
                        <xsl:value-of select="$pluginId"/>/<xsl:value-of select="concat(substring-before(translate($FILENAME, '\', '/'), '.')
                            , '.html')"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:variable>
            
            <xsl:attribute name="path">
                <xsl:value-of select="$path"/>
            </xsl:attribute>
        </xsl:element>
    </xsl:template>
    
</xsl:stylesheet>
