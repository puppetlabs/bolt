/*
 * This file is part of the DITA Open Toolkit project.
 *
 * Copyright 2017 Jarno Elovirta
 *
 *  See the accompanying LICENSE file for applicable license.
 */
package org.dita.dost.writer;

import org.junit.Test;

import java.io.File;

import static org.junit.Assert.assertEquals;

public class TestIDitaTranstypeIndexWriter {

    public static IDitaTranstypeIndexWriter idita2 = new EclipseIndexWriter();

    @Test
    public void testiditatranstypeindexwriter() {
        final String exp = System.getProperty("user.dir") + File.separator + "resources" + File.separator + "index.xml";
        final String outputfilename = "resources" + File.separator + "iditatranstypewriter";
        assertEquals(exp, idita2.getIndexFileName(outputfilename));
    }

}
